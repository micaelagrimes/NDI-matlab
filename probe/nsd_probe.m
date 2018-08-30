classdef nsd_probe < nsd_epochset
% NSD_PROBE - the base class for PROBES -- measurement or stimulation devices
%
% In NSD, a PROBE is an instance of an instrument that can be used to MEASURE
% or to STIMULATE.
%
% Typically, a probe is associated with an NSD_IODEVICE that performs data acquisition or
% even control of a stimulator. 
%
% A probe is uniquely identified by 3 fields:
%    name      - the name of the probe
%    reference - the reference number of the probe
%    type      - the type of probe (see type NSD_PROBETYPE2OBJECTINIT)
%
% Examples:
%    A multichannel extracellular electrode might be named 'extra', have a reference of 1, and
%    a type of 'n-trode'. 
%
%    If the electrode is moved, one should change the name or the reference to indicate that 
%    the data should not be attempted to be combined across the two positions. One might change
%    the reference number to 2.
%
% How to make a probe:
%    (Talk about epochcontents records of devices, probes are created from these elements.)
%   

	properties (GetAccess=public, SetAccess=protected)
		experiment   % The handle of an NSD_EXPERIMENT object with which the NSD_PROBE is associated
		name         % The name of the probe; this must start with a letter and contain no whitespace
		reference    % The reference number of the probe; must be a non-negative integer
		type         % The probe type; must start with a letter and contain no whitespace, and there is a standard list
	end

	methods
		function obj = nsd_probe(experiment, name, reference, type)
			% NSD_PROBE - create a new NSD_PROBE object
			%
			%  OBJ = NSD_PROBE(EXPERIMENT, NAME, REFERENCE, TYPE)
			%
			%  Creates an NSD_PROBE associated with an NSD_EXPERIMENT object EXPERIMENT and
			%  with name NAME (a string that must start with a letter and contain no white space),
			%  reference number equal to REFERENCE (a non-negative integer), the TYPE of the
			%  probe (a string that must start with a letter and contain no white space).
			%
			%  NSD_PROBE is an abstract class, and a specific implementation must be called.
			%

				if ~isa(experiment, 'nsd_experiment'),
					error(['experiment must be a member of the NSD_EXPERIMENT class.']);
				end
				if ~islikevarname(name),
					error(['name must start with a letter and contain no whitespace']);
				end
				if ~islikevarname(type),
					error(['type must start with a letter and contain no whitespace']);
				end
				if ~(isint(reference) & reference >= 0)
					error(['reference must be a non-negative integer.']);
				end

				obj.experiment = experiment;
				obj.name = name;
				obj.reference = reference;
				obj.type = type;

		end % nsd_probe

		function et = epochtable(nsd_probe_obj)
			% EPOCHTABLE - return the epoch table for an NSD_PROBE
			%
			% ET = EPOCHTABLE(NSD_PROBE_OBJ)
			%
			% ET is a structure array with the following fields:
			% Fieldname:                | Description
			% ------------------------------------------------------------------------
			% 'epoch_number'            | The number of the epoch (may change)
			% 'epoch_id'                | The epoch ID code (will never change once established)
			%                           |   This uniquely specifies the epoch.
			% 'epochcontents'           | The epochcontents object from each epoch
			% 'underlying_epochs'       | A structure array of the nsd_epochset objects that comprise these epochs.
			%                           |   It contains fields 'underlying', 'epoch_number', and 'epoch_id'

				ue = emptystruct('underlying','epoch_number','epoch_id','epochcontents');
				et = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');

				% pull all the devices from the experiment and look for device strings that match this probe

				D = nsd_probe_obj.experiment.iodevice_load('name','(.*)');
				if ~iscell(D), D = {D}; end; % make sure it has cell form

				d_et = {};

				for d=1:numel(D),
					d_et{d} = epochtable(D{d});

					for n=1:numel(d_et{d}),
						underlying_epochs = emptystruct('underlying','epoch_number','epoch_id','epochcontents');
						underlying_epochs(1).underlying = D{d};
						if nsd_probe_obj.epochcontentsmatch(d_et{d}(n).epochcontents),
							underlying_epochs.epoch_number = n;
							underlying_epochs.epoch_id = d_et{d}(n).epoch_id;
							underlying_epochs.epochcontents = d_et{d}(n).epochcontents;
							et_ = emptystruct('epoch_number','epoch_id','epochcontents','underlying_epochs');
							et_(1).epoch_number = numel(et);
							et_(1).epoch_id = d_et{d}(n).epoch_id; % this is an unambiguous reference
							et_(1).epochcontents = []; % not applicable for nsd_probe objects
							et_(1).underlying_epochs = underlying_epochs;
							et(end+1) = et_;
						end
					end
				end
		end % epochtable

		function probestr = probestring(nsd_probe_obj)
			% PROBESTRING - Produce a human-readable probe string
			%
			% PROBESTR = PROBESTRING(NSD_PROBE_OBJ)
			%
			% Returns the name and reference of a probe as a human-readable string.
			%
			% This is simply PROBESTR = [NSD_PROBE_OBJ.name ' _ ' in2str(NSD_PROBE_OBJ.reference)]
			%
				probestr = [nsd_probe_obj.name ' _ ' int2str(nsd_probe_obj.reference) ];
		end

		function [dev, devname, devepoch, channeltype, channellist] = getchanneldevinfo(nsd_probe_obj, epoch_number_or_id)
			% GETCHANNELDEVINFO = Get the device, channeltype, and channellist for a given epoch for NSD_PROBE
			%
			% [DEV, DEVNAME, DEVEPOCH, CHANNELTYPE, CHANNELLIST] = GETCHANNELDEVINFO(NSD_PROBE_OBJ, EPOCH_NUMBER_OR_ID)
			%
			% Given an NSD_PROBE object and an EPOCH number, this function returns the corresponding channel and device info.
			% Suppose there are C channels corresponding to a probe. Then the outputs are
			%   DEV is a 1xC cell array of NSD_IODEVICE objects for each channel
			%   DEVNAME is a 1xC cell array of the names of each device in DEV
			%   DEVEPOCH is a 1xC array with the number of the probe's EPOCH on each device
			%   CHANNELTYPE is a cell array of the type of each channel
			%   CHANNELLIST is the channel number of each channel.
			%

				et = epochtable(nsd_probe_obj);

				if ischar(epoch_number_or_id),
					epoch_number = strcmpi(epoch_number_or_id, {et.epochid});
					if isempty(epoch_number),
						error(['Could not identify epoch with id ' epoch_number_or_id '.']);
					end
				else,
					epoch_number = epoch_number_or_id;
				end

				if epoch_number>numel(et),
		 			error(['Epoch number ' epoch_number ' out of range 1..' int2str(numel(et)) '.']);
				end;

				dev = {};
				devname = {};
				devepoch = [];
				channeltype = {};
				channellist = [];
				
				for i = 1:numel(et),
					for j=1:numel(et(i).underlying_epochs),
						devstr = nsd_iodevicestring(et(i).underlying_epochs(j).epochcontents.devicestring);
						[devname_here, channeltype_here, channellist_here] = devstr.nsd_iodevicestring2channel();
						dev{end+1} = et(i).underlying_epochs.underlying; % underlying device
						devname = cat(2,devname,devname_here);
						devepoch = cat(2,devepoch,et(i).underlying_epochs(j).epoch_number);
						channeltype = cat(2,channeltype,channeltype_here);
						channellist = cat(2,channellist,channellist_here);
					end
				end

		end % getchanneldevinfo(nsd_probe_obj, epoch)

		function b = epochcontentsmatch(nsd_probe_obj, epochcontents)
			% EPOCHCONTENTSMATCH - does an epochcontents record match our probe?
			%
			% B = EPOCHCONTENTSMATCH(NSD_PROBE_OBJ, EPOCHCONTENTS)
			%
			% Returns 1 if the NSD_EPOCHCONTENTS object EPOCHCONTENTS is a match for
			% the NSD_PROBE_OBJ probe and 0 otherwise.
			%
				b = strcmp(epochcontents.name,nsd_probe_obj.name) && ...
					(epochcontents.reference==nsd_probe_obj.reference) &&  ...
					strcmp(lower(epochcontents.type),lower(nsd_probe_obj.type));  % we have a match
		end % epochcontentsmatch()

	end % methods
end
