classdef ndi_daqreader_stimulus < ndi_daqreader
% NDI_DAQREADER_STIMULUS - an abstract NDI_DAQREADER class for stimulators

	properties (GetAccess=public,SetAccess=protected)
		tsv_fileparameters   % optional regular expression to search within epochfiles for a
		                     %   tab-separated-value file that describes stimulus
		                     %   parameters
	end
	properties (Access=private) % potential private variables
	end

	methods
		function obj = ndi_daqreader_stimulus(varargin)
			% NDI_DAQREADER_STIMULUS - Create a new multifunction DAQ object
			%
			%  D = NDI_DAQREADER_STIMULUS()
			%  or
			%  D = NDI_DAQREADER_STIMULUS(TSVFILE_REGEXPRESSION)
			%
			%  Creates a new NDI_DAQREADER_STIMULUS object. If TSVFILE_REGEXPRESSION
			%  is given, it indicates a regular expression to use to search EPOCHFILES
			%  for a tab-separated-value text file that describes stimulus parameters.
			% 
				tsv_p = '';
				if nargin==1,
					tsv_p = varargin{1};
					varargin = {};
				end;

				obj = obj@ndi_daqreader(varargin{:});

				if (nargin==2) & (isa(varargin{1},'ndi_session')) & (isa(varargin{2},'ndi_document')),
					if isfield(varargin{2}.document_properties,'ndi_daqreader_stimulus'),
						tsv_p = varargin{2}.document_properties.ndi_daqreader_stimulus.tsv_fileparameters;
					end;
				end;
				obj.tsv_fileparameters = tsv_p;
		end; % ndi_daqreader_stimulus

		function parameters = get_stimulus_parameters(ndi_daqsystem_stimulus_obj, epochfiles)
			% PARAMETERS = NDI_GET_STIMULUS_PARAMETERS(NDI_DAQSYSTEM_STIMULUS_OBJ, EPOCHFILES)
			%
			% Returns the parameters (cell array of structures) associated with the
			% stimulus or stimuli that were prepared to be presented in epoch with file list EPOCHFILES.
			%
			% If the property 'tsv_fileparameters' is not empty, then EPOCHFILES will be searched for
			% files that match the regular expression in 'tsv_fileparameters'. The tab-separated-value
			% file should have the form:
			%
			% STIMID<tab>PARAMETER1<tab>PARAMETER2<tab>PARAMETER3 (etc) <newline>
			% 1<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc) <newline>
			% 2<tab>VALUE1<tab>VALUE2<tab>VALUE3 (etc) <newline>
			%  (etc)
			%
			% For example, a stimulus file for an interoral cannula might be:
			% stimid<tab>substance1<tab>substance1_concentration<newline>
			% 1<tab>Sodium chloride<tab>30e-3<newline>
			% 2<tab>Sodium chloride<tab>300e-3<newline>
			% 3<tab>Quinine<tab>30e-6<newline>
			% 4<tab>Quinine<tab>300e-6<newline>
			%
			% This function can be overridden in more specialized stimulus classes.
			%
				parameters = {};
				if ~isempty(ndi_daqsystem_stimulus_obj.tsv_fileparameters),
					tf = find(regexpi(ndi_daqsystem_stimulus_obj.tsv_fileparameters, epochfiles,'forceCellOutput'));
					if numel(tf)>1,
						error(['More than one epochfile matches regular expression ' ...
							ndi_daqsystem_stimulus_obj.tsv_fileparameters ...
							'; epochfiles were ' epochfiles{:} '.']);
					elseif numel(tf)==0,
						error(['No epochfiles match regular expression ' ...
							ndi_daqsystem_stimulus_obj.tsv_fileparameters ...
							'; epochfiles were ' epochfiles{:} '.']);

					else,
						stimparameters = loadStructArray(epochfiles{tf});
						for i=1:numel(stimparameters),
							parameters{i} = stimparameters(i);
						end;
					end;
				end;
                end; % get_stimulus_parameters()

		% methods that override ndi_documentservice

		function ndi_document_obj = newdocument(ndi_daqreader_stimulus_obj)
			% NEWDOCUMENT - create a new NDI_DOCUMENT for an NDI_DAQREADER_STIMULUS object
			%
			% DOC = NEWDOCUMENT(NDI_DAQREADER_STIMULUS OBJ)
			%
			% Creates an NDI_DOCUMENT object DOC that represents the
			%    NDI_DAQREADER object.
				ndi_document_obj = ndi_document('ndi_document_daqreader_stimulus.json',...
					'daqreader.ndi_daqreader_class',class(ndi_daqreader_stimulus_obj),...
					'daqreader_stimulus.ndi_daqreader_stimulus_class',class(ndi_daqreader_stimulus_obj),...
					'daqreader_stimulus.tsv_fileparameters', ndi_daqreader_stimulus_obj.tsv_fileparameters, ...
					'ndi_document.id', ndi_daqreader_stimulus_obj.id());
		end; % newdocument()

	end; % methods
end % classdef

