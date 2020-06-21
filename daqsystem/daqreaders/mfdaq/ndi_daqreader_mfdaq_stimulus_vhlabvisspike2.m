% NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2 - Device object for vhlab visual stimulus computer
%
% This device reads the 'stimtimes.txt', 'verticalblanking.txt', 'stims.mat', and 'spike2data.smr' files
% that are present in directories where a VHLAB stimulus computer (running NewStim/RunExperiment)
% has produced triggers that have been acquired on a CED Spike2 system running the VHLAB Spike2 script.
%
% This device produces the following channels in each epoch:
% Channel name:   | Signal description:
% ----------------|------------------------------------------
% m1              | stimulus on/off
% m2              | stimid 
% e1              | frame trigger
% e2              | vertical refresh trigger
% e3              | pretime trigger
%

classdef ndi_daqreader_mfdaq_stimulus_vhlabvisspike2 < ndi_daqreader_mfdaq & ndi_daqreader_stimulus
	properties (GetAcces=public,SetAccess=protected)

	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = ndi_daqreader_mfdaq_stimulus_vhlabvisspike2(varargin)
			% NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2 - Create a new multifunction DAQ object
			%
			%  D = NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2(NAME, THEFILENAVIGATOR, DAQREADER)
			%
			%  Creates a new NDI_DAQSYSTEM_MFDAQ object with NAME, and FILENAVIGATOR.
			%  This is an abstract class that is overridden by specific devices.
				obj = obj@ndi_daqreader_mfdaq(varargin{:});
		end; % ndi_daqreader_mfdaq_stimulus_vhlabvisspike2()

		function ec = epochclock(ndi_daqreader_mfdaq_stimulus_vhlabvisspike2_obj, epochfiles)
			% EPOCHCLOCK - return the NDI_CLOCKTYPE objects for an epoch
			%
			% EC = EPOCHCLOCK(NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2_OBJ, EPOCHFILES)
			%
			% Return the clock types available for this epoch as a cell array
			% of NDI_CLOCKTYPE objects (or sub-class members).
			%
			% This returns a single clock type 'dev_local'time';
			%
			% See also: NDI_CLOCKTYPE
			%
				ec = {ndi_clocktype('dev_local_time')};
		end % epochclock

		function channels = getchannelsepoch(thedev, epochfiles)
			% FUNCTION GETCHANNELS - List the channels that are available on this device
			%
			%  CHANNELS = GETCHANNELSEPOCH(THEDEV, EPOCHFILES)
			%
			% This device produces the following channels in each epoch:
			% Channel name:   | Signal description:
			% ----------------|------------------------------------------
			% mk1             | stimulus on/off
			% mk2             | stimid 
			% mk3             | stimulus open/close
			% e1              | frame trigger
			% e2              | vertical refresh trigger
			% e3              | pretime trigger
			%
				channels        = struct('name','mk1','type','marker');  
				channels(end+1) = struct('name','mk2','type','marker');  
				channels(end+1) = struct('name','mk3','type','marker');  
				channels(end+1) = struct('name','e1','type','event');  
				channels(end+1) = struct('name','e2','type','event');  
				channels(end+1) = struct('name','e3','type','event');  
		end; % getchannelsepoch()

		function data = readevents_epoch(ndi_daqreader_mfdaq_stimulus_vhlabvisspike2_obj, channeltype, channel, epochfiles, t0, t1)
			%  FUNCTION READEVENTS - read events or markers of specified channels for a specified epoch
			%
			%  DATA = READEVENTS(SELF, CHANNELTYPE, CHANNEL, EPOCHFILES, T0, T1)
			%
			%  SELF is the NDI_DAQSYSTEM_MFDAQ_STIMULUS_VHVISSPIKE2 object.
			%
			%  CHANNELTYPE is a cell array of strings describing the the type(s) of channel(s) to read
			%  ('event','marker', etc)
			%  
			%  CHANNEL is a vector with the identity of the channel(s) to be read.
			%  
			%  EPOCH is the cell array of file names associated with an epoch
			%
			%  DATA is a two-column vector; the first column has the time of the event. The second
			%  column indicates the marker code. In the case of 'events', this is just 1. If more than one channel
			%  is requested, DATA is returned as a cell array, one entry per channel.
			%  
				data = {};

				pathname = {};
				fname = {};
				ext = {};
				for i=1:numel(epochfiles),
					[pathname{i},fname{i},ext{i}] = fileparts(epochfiles{i});
				end

				% do the decoding
				[stimid,stimtimes,frametimes] = read_stimtimes_txt(pathname{1});
				mappingfile1 = [pathname{1} filesep 'stimtimes2stimtimes_mapping.txt'];
				if exist(mappingfile1,'file'),
					mapping = load(mappingfile1,'-ascii');
					stimid = stimid(dropnan(mapping));
					stimtimes = stimtimes(dropnan(mapping));
					frametimes = frametimes(dropnan(mapping));
				end
				[ss,mti]=getstimscript(pathname{1});
				mappingfile2 = [pathname{1} filesep 'mti2stimtimes_mapping.txt'];
				if exist(mappingfile2,'file'),
					mapping = load(mappingfile2,'-ascii');
					mti = mti(dropnan(mapping));
				end
				stimofftimes = [];
				stimsetuptimes = [];
				stimcleartimes = [];
				if numel(mti)~=numel(stimtimes),
					error(['Error: The number of stim triggers present in the stimtimes.txt file (' int2str(numel(stimtimes)) ') differs from what is expected from the content of stims.mat file (' int2str(length(mti)) ') in ' pathname{1} '.']);
				end

				for i=1:numel(mti),
					% spike2time = mactime + timeshift
					timeshift = stimtimes(i) - mti{i}.startStopTimes(2);
					stimofftimes(i) = mti{i}.startStopTimes(3) + timeshift;
					stimsetuptimes(i) = mti{i}.startStopTimes(1) + timeshift;
					stimcleartimes(i) = mti{i}.startStopTimes(4) + timeshift;
				end;

				for i=1:numel(channel),
					%ndi_daqsystem_mfdaq.mfdaq_prefix(channeltype{i}),
					switch (ndi_daqsystem_mfdaq.mfdaq_prefix(channeltype{i})),
						case 'mk',
							% put them together, alternating stimtimes and stimofftimes in the final product
							time1 = [stimtimes(:)' ; stimofftimes(:)'];
							data1 = [ones(size(stimtimes(:)')) ; -1*ones(size(stimofftimes(:)'))];
							time1 = reshape(time1,numel(time1),1);
							data1 = reshape(data1,numel(data1),1);
							ch{1} = [time1 data1];
							
							time2 = [stimtimes(:)];
							data2 = [stimid(:)];
							ch{2} = [time2 data2];

							time3 = [stimsetuptimes(:)' ; stimcleartimes(:)'];
							data3 = [ones(size(stimsetuptimes(:)')) ; -1*ones(size(stimcleartimes(:)'))];
							time3 = reshape(time3,numel(time3),1);
							data3 = reshape(data3,numel(data3),1);
							ch{3} = [time3 data3];

							data{i} = ch{channel(i)};
						case 'e',
							if channel(i)==1, % frametimes
								allframetimes = cat(1,frametimes{:});
								data{end+1} = [allframetimes(:) ones(size(allframetimes(:)))];
							elseif channel(i)==2, % vertical refresh
								vr = load(epochfiles{find(strcmp('verticalblanking',fname))},'-ascii');
								data{end+1} = [vr(:) ones(size(vr(:)))];
							elseif channel(i)==3, % background trigger, simulated
								data{end+1} = [stimsetuptimes(:) ones(size(stimsetuptimes(:)))];
							end
						otherwise,
							error(['Unknown channel.']);
					end
				end

				if numel(data)==1,% if only 1 channel entry to return, make it non-cell
					data = data{1};
				end; 

		end % readevents_epochsamples()

		function t0t1 = t0_t1(ndi_daqreader_mfdaq_stimulus_vhlabvisspike2_obj, epochfiles)
			% EPOCHCLOCK - return the t0_t1 (beginning and end) epoch times for an epoch
			%
			% T0T1 = T0_T1(NDI_DAQREADER_MFDAQ_STIMULUS_VHLABVISSPIKE2_OBJ, EPOCH_NUMBER)
			%
			% Return the beginning (t0) and end (t1) times of the epoch EPOCH_NUMBER
			% in the same units as the NDI_CLOCKTYPE objects returned by EPOCHCLOCK.
			%
			%
			% See also: NDI_CLOCKTYPE, EPOCHCLOCK
			%
				filename = ndi_daqreader_mfdaq_cedspike2.cedspike2filelist2smrfile(epochfiles);
				header = read_CED_SOMSMR_header(filename);

				t0 = 0;  % developer note: the time of the first sample in spike2 is not 0 but 0 + 1/4 * sample interval; might be more correct to use this
				t1 = header.fileinfo.dTimeBase * header.fileinfo.maxFTime * header.fileinfo.usPerTime;
				t0t1 = {[t0 t1]};
		end % t0t1

		function sr = samplerate(ndi_daqreader_mfdaq_stimulus_vhlabvisspike2_obj, epochfiles, channeltype, channel)
			%
			% SAMPLERATE - GET THE SAMPLE RATE FOR SPECIFIC CHANNEL
			%
			% SR = SAMPLERATE(DEV, EPOCHFILES, CHANNELTYPE, CHANNEL)
			%
			% SR is an array of sample rates from the specified channels
			%
			   %so, these are all events, and it doesn't much matter, so
			   % let's make a guess that should apply well in all cases

			sr = 1e-4 * ones(size(channel));
		end

		function parameters = get_stimulus_parameters(ndi_daqsystem_stimulus_obj, epochfiles)
			%
			% PARAMETERS = NDI_GET_STIMULUS_PARAMETERS(NDI_DAQSYSTEM_STIMULUS_OBJ, EPOCHFILES)
			%
			% Returns the parameters (cell array of structs) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch with file list EPOCHFILES.
			%
			% In this case, it is the parameters of NEWSTIM stimuli from the VHLab visual stimulus system.
			%

				pathname = {};
				fname = {};
				ext = {};
				for i=1:numel(epochfiles),
					[pathname{i},fname{i},ext{i}] = fileparts(epochfiles{i});
				end

				index = find(strcmp('stims',fname));
				[ss,mti]=getstimscript(pathname{index});

				parameters = {};
				for i=1:numStims(ss),
					parameters{i} = getparameters(get(ss,i));
				end;
		end

	end; % methods

	methods (Static)  % helper functions
	end % static methods
end

