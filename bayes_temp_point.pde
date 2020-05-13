import processing.net.*; 
import processing.sound.*;
Client myClient;

// Position of basic components
int bar_x = 60;
int bar_y = 220;
int bar_width = 600;
int bar_height = 25;
int bullet_width = 25;
int bullet_height = bar_height;
int target_x = bar_x + 80;
int target_zone_width = 50;
int target_zone_height = bar_height;
int target_center = target_x + (target_zone_width/2);
int button_x = 300;
int button_y = 300;
int button_width = 60;
int button_height = 30;
float bullet_x, bullet_y;    // Starting position of bullet    
int frame_rate = 120;

// Color
color white = color(255, 255, 255);
color black = color(0,0,0);
color yellow = color(255, 204, 0);
color red = color(255,0,0);
color blue = color(0,0,255);
color grey = color(90,90,90);

// The parameters for the optimization task
int press_init = 0;  // Record the press start timestamp
int draw_effect_frames = 90;    // This parameter decides the length of the activation visual effect
int draw_effect_count = draw_effect_frames; // Don't change this one. It simply cancels the activation effect
float pix_diff = 0;      // For calculate the pixel error
float t_diff = 0;        // For calculate the time error (unit ms)
SoundFile sound_file;    // This parameter stores the current soundfile for playing
int dataIn = 0;

int xdirection = -1;  // Left or Right. No need to change this one at all!
float xspeed = 5;  // Speed of the shape. Task difficulty is here
int activation_point = 10; // The latency between press starts (press_init) and the button activated. (unit ms)
int sound_point = 10;  // The latency between press starts (press_init) and the sound played. (unit ms)

boolean played = false;
boolean pressed = false;
int button_status = 0; // 0 for before activate, 1 for activate, 2 for after activate
int play_count = 0;
int iteration_count = 0;
int penalty = 0; // If the button released before activated or sound played, we 

void setup() 
{
  size(720, 480);
  noStroke();
  frameRate(frame_rate);
  // Set the starting position of the shape
  bullet_x = bar_x + bar_width - 1*bullet_width;
  bullet_y = bar_y;
  myClient = new Client(this, "127.0.0.1", 50007);  // Starting connection
  //sound_file = new SoundFile(this, "output2.wav");
}

void draw() 
{
  // If there is any signal from python, we reset the button 
  if (myClient.available() > 0) 
  {
     dataIn = myClient.read();
     activation_point = dataIn; 
     print("Reset activation point: ");
     println(activation_point);
     dataIn = myClient.read();
     sound_point = dataIn;
     print("Reset sound point: ");
     println(sound_point);

     // Delay this for waiting the sound file is created by python
     delay(1000);
     
     // Now we read the sound file with a specific file name
     // I don't know why, but if we modify the same file from python and re-read it, it won't work
     String file_name = "output_";
     file_name = file_name.concat(str(iteration_count)).concat(".wav");
     print ("opening the sound file: ");
     println(file_name);
     sound_file = new SoundFile(this, file_name);
     iteration_count += 1;
     // If the sound hasn't been played yet, mute it
     if (played == false && pressed == true)
     {played = true;}
  }
  
  // Basic drawing
  background(200);
  fill(white);
  rect(bar_x, bar_y, bar_width, bar_height);
  
  fill(yellow);
  rect(target_x, bar_y, target_zone_width, target_zone_height);
  fill(grey);
  rect(button_x, button_y, button_width, button_height);
  textSize(20);
  fill(white);
  text("click", button_x+8, button_y+22);
  
  
  
  // Button was pressed (from a non-pressed status)
  if(mousePressed)
  {
    // Only care when the pressed is upon the button
    if(mouseX>button_x && mouseX <button_x + button_width && mouseY>button_y && mouseY <button_y+button_height && pressed == false)
    {
      press_init = millis(); 
      pressed = true;
    }
  }
  
  // Button was released (finger lifted from the button)
  // There will be 3 possible case, each triggers different outcome sends to the python backend
  // 1. The button hasn't been activated before you already released, we give it a penalty
  // 2. The sound hasn't been played, we give it a penalty
  // 3. The regular case. The button is activated and the sound is played. We then send the actual temporal error.
  if (mousePressed==false && pressed == true)
  {
    // 1. finger lift the button even before it's activated 
    if (button_status == 0) 
    {
      draw_effect_count = 0; // this will change the color of the bullet
      // activate
      pix_diff = bullet_x - target_center;              // pixel difference
      t_diff = ((pix_diff/xspeed) * 1000 )/ frame_rate; // the difference convert in time (ms)
      //print ("distance = ");
      //print (pix_diff);
      //print ("; temporal diff = ");
      //println (t_diff);
      penalty = 500;       // arbitrary penalty for this case
      
      if (played == false) // if the sound feedback is not generated as well, we raise the penalty
      {sound_file.play(); penalty += 200;}
      print ("  penalty = ");
      println(penalty);
      myClient.write(str(penalty));
    }
    // 2. Here the case is that the finger lift the button, it is activated but not the sound
    else if (played == false)
    {
      penalty = 400;// arbitrary penalty
      sound_file.play();
      print ("  penalty = ");
      println(penalty);
      myClient.write(str(penalty));
    }
    // 3. This is the ideal case, that the button is activated and feedback generated before released
    else
    {myClient.write(str(t_diff));}
    penalty = 0;
    //int duration = millis() - press_init;
    //println (duration);
    
    // and reset everything
    pressed = false;
    played = false;
    button_status = 0;
  }
  
  // Here handles the situation during the button is pressed (before released)
  if (pressed)
  {
    if (button_status ==0)
    {
      if (millis() - press_init >= activation_point)
      {
        //println("button activate");
        button_status = 1;
        draw_effect_count = 0;
        pix_diff = bullet_x - target_center;              // pixel difference
        t_diff = ((pix_diff/xspeed) * 1000 )/ frame_rate; // the difference convert in time (ms)
        //print ("distance = ");
        //print (pix_diff);
        print ("  temporal diff = ");
        println (t_diff);
      }
    }
    else if (button_status == 1)
    {button_status = 2;}
    if (millis() - press_init >= sound_point && played == false)
    {
      sound_file.play(); 
      played = true;
    }
  }
  
  // Draw the bullet 
  fill(red); // the default color of the bullet
  // When it's activated, the color is blue
  if (draw_effect_count < draw_effect_frames)
  {
    fill(blue);
    draw_effect_count += 1;
  }
  rect(bullet_x, bullet_y, bullet_width, bullet_height);
  // Update the position of the bullet
  bullet_x = bullet_x + ( xspeed * xdirection );
  // if the shape exceeds the boundaries of the screen
  if (bullet_x <= bar_x) 
  {
    bullet_x = bar_x + bar_width - 1*bullet_width; // Reset the bullet
    draw_effect_count = draw_effect_frames;  // cancel the visual effect
  }
}
