function test_nsd_device_image_tiffstack( input_file_directory )
%UNTITLED5 Summary of this function goes here
%   Detailed explanation goes here

global epoch_number frame_number;
epoch_number = 1;
%The epoch to be tested by both .frame(n,i), and .numFrame(n). Could be changed for testing.
frame_number = 1;
%the frame to be taken using .frame(n,i) function. Could be changed for testing

%Makes sure that the input_file_directory argument is indeed a directory,
%and that only one arguments is passed.
%If no argument is passed, then set the directories to a
%default.
if nargin < 1
    example_directory = [userpath filesep 'tools' filesep 'NSD' filesep 'example_experiments'];
    input_dir_name = [example_directory filesep 'exp1' filesep 'raw_data' ];
    output_dir_name = [example_directory filesep 'exp1' filesep 'output' ];
elseif exist(input_file_directory) ~= 7
    error('argument is not a directory');
else
    input_dir_name = input_file_directory;
    dir_parts = strsplit(input_dir_name, filesep);
    parent_dir = strjoin(dir_parts(1:end-1), filesep);
    output_dir_name = [parent_dir filesep 'output'];
end

%creating a new experiment object
example_exp = nsd_experiment_dir('exp1',input_dir_name);
%creating a new filetree that looks for .tif files.
example_filetree = nsd_filetree(example_exp.getpath,'.*\.tif\>');
%creating an image_tiffstack device object
example_device = nsd_device_image_tiffstack('sampleDevice',example_filetree);



disp('Counting the number of frames in the first epoch');
disp(['The first epoch has ' num2str(example_device.numFrame(epoch_number)) ' frames']);

disp(['Collecting frame number ' num2str(frame_number) ' from epoch number ' num2str(epoch_number)]);
image = example_device.frame(epoch_number,frame_number);
imwrite(image, [output_dir_name filesep 'example_frame.tif']);
disp(['frame exported to "' output_dir_name '"']);

end
