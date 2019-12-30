function epochdemo1
% EPOCHDEMO1 - Demonstrate the relationship between epochs, daqsystems, probes, and things
%
%  EPOCHDEMO1
%
%  This is the code that forms the basis for the Jupyter notebook: epochdemo1.ipynb
%

ndi_globals;
dirname = [ndiexampleexperpath filesep 'intracell_example'];

disp(['creating a new experiment object...']);
E = ndi_experiment_dir('exp1',dirname);

disp(['Now adding our acquisition device (CED Spike2):']);

  % A NDI_DAQSYSTEM requires two objects: an ndi_filenavigator that describes
  %  where the files are stored on disk, and an ndi_daqreader that describes
  % how to read the files. Further, this daqsystem is a multifunction daq, which
  % allows simultaneous (potential) use of analog inputs, analog outputs, digital inputs,
  % digital outputs, and a clock. 

  % Step 1.1: Prepare the ndi_filenavigator; we will just look for .smr
  %         files in any organization within the directory that also have a corresponding
  %         .epochmetadata file that describes the probes that were acquired during each
  %         epoch.

fn = ndi_filenavigator(E, {'.*\.smr\>','.*\.epochmetadata\>'},...
	'ndi_epochprobemap_daqsystem','.*\.epochmetadata\>');  % look for .smr files and .epochmetadata files


  % Step 1.2: create the daqsystem object and add it to the experiment:

dev1 = ndi_daqsystem_mfdaq('myspike2',fn, ndi_daqreader_mfdaq_cedspike2());
E.daqsystem_add(dev1);

  % Now let's explore the epochs that are here

  % Now let's print some statistics

disp(['The channels we have on this daqsystem are the following:']);

disp ( struct2table(getchannels(dev1)) );

sr_d = samplerate(dev1,1,{'digital_in'},1);
sr_a = samplerate(dev1,1,{'analog_in'},1);

disp(['The sample rate of digital channel 1 in epoch 1 is ' num2str(sr_d) '.']);
disp(['The sample rate of analog channel 1 in epoch 1 is ' num2str(sr_a) '.']);

disp(['We will now plot the data for epoch 1 for analog_input channel 1.']);

data = readchannels_epochsamples(dev1,{'analog_in'},21,1,0,Inf);
time = readchannels_epochsamples(dev1,{'time'},21,1,0,Inf);

figure;
plot(time,data);
ylabel('Data');
xlabel('Time (s)');
box off;

E.daqsystem_rm(dev1); % remove the daqsystem so the demo can run again

