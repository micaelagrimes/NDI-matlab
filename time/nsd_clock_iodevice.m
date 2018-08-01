classdef nsd_clock_iodevice < nsd_clock
% NSD_CLOCK_IODEVICE - a class for specifying time in the NSD framework for clocks that are linked to NSD_IODEVICE objects
%
%
	properties (SetAccess=protected, GetAccess=public)
		iodevice % the nsd_iodevice object associated with the clock
	end

	methods
		function obj = nsd_clock_iodevice(type, iodevice)
			% NSD_CLOCK_IODEVICE - Creates a new NSD_CLOCK_DEVICE object, an NSD_CLOCK associated with a device
			%
			% OBJ = NSD_CLOCK_IODEVICE(TYPE, IODEVICE)
			%
			% Creates a new NSD_CLOCK object for the device DEVICE. TYPE can be
			% any of the following strings (with description):
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
                        % 'utc'              | The device keeps universal coordinated time (within 0.1ms)
                        % 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
                        % 'no_time'          | The device has no timing information
			% 'dev_global_time'  | The device has a global clock for itself
			% 'dev_local_time'   | The device only has local time, within a recording epoch
			%
				obj = obj@nsd_clock();

				obj.type = '';
				obj.iodevice = [];

				if ~isa(iodevice,'nsd_iodevice') & ~isempty(iodevice),
					error(['DEVICE must be of type NSD_IODEVICE.']);
				else,
					obj.iodevice = iodevice;
				end
				if nargin>0,
					obj = setclocktype(obj,type);
				end

		end % nsd_clock_iodevice()
		
		function nsd_clock_iodevice_obj = setclocktype(nsd_clock_iodevice_obj, type)
			% SETCLOCKTYPE - Set the type of an NSD_CLOCK_IODEVICE
			%
			% NSD_CLOCK_IODEVICE_OBJ = SETCLOCKTYPE(NSD_CLOCK_IODEVICE_OBJ, TYPE)
			%
			% Sets the TYPE property of an NSD_CLOCK_IODEVICE object NSD_CLOCK_IODEVICE_OBJ.
			% Valid values for the TYPE string are as follows:
			%
			% TYPE string        | Description
			% ------------------------------------------------------------------------------
			% 'utc'              | The device keeps universal coordinated time (within 0.1ms)
			% 'exp_global_time'  | The device keeps experiment global time (within 0.1ms)
			% 'dev_global_time'  | The device has a global clock for itself
			% 'dev_local_time'   | The device only has local time, within a recording epoch
			% 'no_time'          | The device has no timing information
			%
				if ~ischar(type),
					error(['TYPE must be a character string.']);
				end

				try,
					nsd_clock_iodevice_obj = setclocktype@nsd_clock_iodevice_obj(nsd_clock_device_obj,type);
				catch,
					type = lower(type);
					switch type,
						case {'dev_global_time','dev_local_time'},
							% no error
						otherwise,
							error(['Unknown clock type ' type '.']);
					end
					nsd_clock_iodevice_obj.type = type;
				end
		end % setclocktype() %

		function nsd_clock_iodevice_struct = clock2struct(nsd_clock_iodevice_obj)
			% CLOCK2STRUCT - create a structure version of the clock that lacks handles
			%
			% NSD_CLOCK_IODEVICE_STRUCT = CLOCK2STRUCT(NSD_CLOCK_IODEVICE_OBJ)
			%
			% Return a structure with information that uniquely specifies an NSD_CLOCK_IODEVICE_OBJ
			% within an NSD_EXPERIMENT but does not contain handles.
			%
			% This function is useful for saving a clock to disk.
			%
			% NSD_CLOCK_IODEVICE_STRUCT contains the following fields:
			% Fieldname              | Description
			% --------------------------------------------------------------------------
			% 'type'                 | The 'type' field of NSD_CLOCK_IODEVICE_OBJ
			% 'nsd_iodevice_name'    | The name of the NSD_IODEVICE in the 'iodevice' field of NSD_CLOCK_IODEVICE_OBJ
			% 'nsd_iodevice_class'   | The class of the NSD_IODEVICE in the 'iodevice' field of NSD_CLOCK_IODEVICE_OBJ
			%
				nsd_clock_iodevice_struct = clock2struct@nsd_clock(nsd_clock_iodevice_obj);
				nsd_clock_iodevice_struct.nsd_iodevice_name = nsd_clock_iodevice_obj.iodevice.name;
				nsd_clock_iodevice_struct.nsd_iodevice_class = class(nsd_clock_iodevice_obj.iodevice);
		end % clock2struct()

		function b = isclockstruct(nsd_clock_iodevice_obj, nsd_clock_struct)
			% ISCLOCKSTRUCT - is an nsd_clock_struct description equivalent to this clock?
			%
			% B = ISCLOCKSTRUCT(NSD_CLOCK_IODEVICE_OBJ, NSD_CLOCK_STRUCT)
			%
			% Returns 1 if NSD_CLOCK_STRUCT is an equivalent description to NSD_CLOCK_IODEVICE_OBJ.
			% Otherwise returns 0.
			% 
			% The property/fields 'type', 'nsd_iodevice_name', and 'nsd_iodevice_class' are examined.
			%
				b = isclockstruct@nsd_clock(nsd_clock_iodevice_obj, nsd_clock_struct);
				if b&isfield(nsd_clock_struct,'nsd_iodevice_name'),
					b = strcmp(nsd_clock_iodevice_obj.iodevice.name, nsd_clock_struct.nsd_iodevice_name);
				else,
					b = 0;
				end
				if b&isfield(nsd_clock_struct,'nsd_iodevice_class'),
					b = strcmp(class(nsd_clock_iodevice_obj.iodevice), nsd_clock_struct.nsd_iodevice_class);
				else,
					b = 0;
				end
		end % isclockstruct()

		function b = eq(nsd_clock_iodevice_obj_a, nsd_clock_iodevice_obj_b)
		% EQ - are two NSD_CLOCK_IODEVICE objects equal?
		%
		% B = EQ(NDS_CLOCK_IODEVICE_OBJ_A, NSD_CLOCK_IODEVICE_OBJ_B)
		%
		% Compares two NSD_CLOCK_IODEVICE objects and returns 1 if they refer to the same
		% iodevice and have the same clock type.
		%
			b = eq@nsd_clock(nsd_clock_iodevice_obj_a,nsd_clock_iodevice_obj_b);
			if b,
				b = nsd_clock_iodevice_obj_a.iodevice==nsd_clock_iodevice_obj_b.iodevice;
			end
		end % eq()

	end % methods
end % nsd_clock_iodevice class


