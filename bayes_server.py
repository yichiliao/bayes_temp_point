import socket
import math
import wave
import struct
import random
import numpy as np

# More info about BO is here:
# https://github.com/fmfn/BayesianOptimization
from bayes_opt import BayesianOptimization

##### The function for optimization 
##### No need to change here as long as you don't include more parameters
def optimize_function(a_point, s_point, s_fre):
    global audio 
    global iteration_count
    global alpha
    global sample_times
    audio = []

    # Send the activation point to processing
    send_data = bytes([int(a_point)])
    conn.sendall(send_data)
    # Send the sound point to processing
    send_data = bytes([int(s_point)])
    conn.sendall(send_data)

    # Generate the wav data for processing to play
    append_sinewave(freq = s_fre)
    file_name = "output_" + str(iteration_count) + ".wav"
    #print(file_name)
    save_wav(file_name)
    
    # Now, we start collecting data sent from processing
    rec_count = 0
    t_diffs = []
    while(rec_count< sample_times + 1):
        data = conn.recv(1024)
        if data: 
            t_diff = round(float(data.decode("utf-8")) , 2)
            #print ('Temporal difference is %.2f' %t_diff)
            t_diffs.append(t_diff)
            rec_count += 1
    # Don't take the last data point into account.
    # Because in some cases, the button is activated before the sound being played
    # In this case, the last data point will be without feedback (the processing is reseting itself)
    # Hence, we just ignore one data point for more consistency.
    t_diffs = np.array(t_diffs[0:-1])
    t_diffs_mean = np.mean(t_diffs)
    t_diffs_std = np.std(t_diffs)
    #print ('The mean of this iteration is %.2f', t_diffs_mean)
    #print ('The std of this iteration is %.2f', t_diffs_std)
    loss_value = - (alpha * abs(t_diffs_mean) + (1-alpha) * t_diffs_std)
    iteration_count += 1
    #print("End of one iteration")
    return loss_value
    
##### Functions for handling sound files
##### Don't change anything here
def append_silence(duration_milliseconds=500):
    """
    Adding silence is easy - we add zeros to the end of our array
    """
    num_samples = duration_milliseconds * (sample_rate / 1000.0)
    for x in range(int(num_samples)): 
        audio.append(0.0)
    return


def append_sinewave(
        freq=440.0, 
        duration_milliseconds=100, 
        volume=1.0):
    """
    The sine wave generated here is the standard beep.  If you want something
    more aggresive you could try a square or saw tooth waveform.   Though there
    are some rather complicated issues with making high quality square and
    sawtooth waves... which we won't address here :) 
    """ 
    global audio # using global variables isn't cool.
    num_samples = duration_milliseconds * (sample_rate / 1000.0)
    for x in range(int(num_samples)):
        audio.append(volume * math.sin(2 * math.pi * freq * ( x / sample_rate )))
    return

def save_wav(file_name):
    # Open up a wav file
    wav_file=wave.open(file_name,"w")
    # wav params
    nchannels = 1
    sampwidth = 2

    # 44100 is the industry standard sample rate - CD quality.  If you need to
    # save on file size you can adjust it downwards. The stanard for low quality
    # is 8000 or 8kHz.
    nframes = len(audio)
    comptype = "NONE"
    compname = "not compressed"
    wav_file.setparams((nchannels, sampwidth, sample_rate, nframes, comptype, compname))

    # WAV files here are using short, 16 bit, signed integers for the 
    # sample size.  So we multiply the floating point data we have by 32767, the
    # maximum value for a short integer.  NOTE: It is theortically possible to
    # use the floating point -1.0 to 1.0 data directly in a WAV file but not
    # obvious how to do that using the wave module in python.
    for sample in audio:
        wav_file.writeframes(struct.pack('h', int( sample * 32767.0 )))
    wav_file.close()
    return
##### End of sound handling functions
######

##### Main function start here
HOST = '' 
PORT = 50007              # Arbitrary non-privileged port

# Sound parameters and setup server
audio = []
sample_rate = 44100.0
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind((HOST, PORT))
s.listen(1)
print ('Server starts, waiting for connection...')
conn, addr = s.accept()
# Now the connection is done
print('Connected by', addr)

# You may change these two values for trial different results
alpha = 0.9       # Alpha value decide the weight of 2 obbjectives
sample_times = 10 # How many presses will be taken into account per iteration

iteration_count = 0

'''
### Just for testing the connection without actually using the optimizer
a_point = 29.5345 # Arbitrary number
s_point = 23.5641 # Arbitrary number
fre = 300.5       # Arbitrary number

for i in range(20):
    results = optimize_function(a_point, s_point, fre)
    print(results)
'''

### Setting parameter bounds
pbounds = {'a_point': (10, 150), 's_point': (10, 150), 's_fre': (300,2000)}

### Setup the optimizer 
optimizer = BayesianOptimization(
    f=optimize_function,
    pbounds=pbounds,
    random_state=1,
)

### Optimizing...
### init_points <- How many random steps you want to do
### n_iter <- How many optimization steps you want to take
optimizer.maximize(
    init_points=10,
    n_iter=10,
)

### Print the best
print(optimizer.max)

### If you want to print all the iterations, uncomment below 2 lines
#for i, res in enumerate(optimizer.res):
#    print("Iteration {}: \n\t{}".format(i, res))

# Close the server
conn.close()