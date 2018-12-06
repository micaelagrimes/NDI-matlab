classdef nsd_document
	%NSD_DOCUMENT - NSD_database storage item, general purpose data and parameter storage
	% The NSD_DOCUMENT datatype for storing results in the NSD_DATABASE
	%
	% The nsd_document_properties field is a structure with properties that are required of all
	% NSD_DOCUMENT objects. These include:
	% Field (default value)           | Description
	% -----------------------------------------------------------------------------------
	% experiment_unique_reference     | The experiment's unique reference ID
	%         (no default)   
	% document_unique_reference       | This document's unique reference id
	% name ('generic')                | The document's name
	% type ('generic')                | The document's type
	% document_version (1)            | The document's version (32-bit unsigned integer numbered from 1)
	% datestamp (current time)        | The document's creation time (for this version) in ISO 8601 (UTC required)
	% database_version (1)            | The version of the database for which the document was created
	% hasbinaryfile (0)               | Should the document have a separate space for storing binary data?
	% validation_schema (no default)  | The validation schema target
	%

	properties (SetAccess=protected,GetAccess=public)
		nsd_document_properties % a struct with the fields for the document
	end

	methods
		function nsd_document_obj = nsd_document(document_type, varargin)
			% NSD_DOCUMENT - create a new NSD_DATABASE object
			%

				nsd_document_obj = nsd_document.readblankdefinition('document_type');
				experiment_unique_reference = '';
				document_unique_reference = [num2hex(now) '_' num2hex(rand)];
				document_version = uint32(1);
				datestamp = char(datetime('now','TimeZone','UTCLeapSeconds'));
				hasbinaryfile = 0;

				nsd_document_properties = emptystruct;

				assign(varargin{:});

				nsd_document_obj.nsd_document_properties.nsd_document = emptystruct;

		end % nsd_document() creator

		function b = validate(nsd_document_obj)
			% VALIDATE - 0/1 evaluate whether NSD_DOCUMENT object is valid by its schema
			% 
			% B = VALIDATE(NSD_DOCUMENT_OBJ)
			%
			% Checks the fields of the NSD_DOCUMENT object against the schema in 
			% NSD_DOCUMENT_OBJ.nsd_core_properties.validation_schema and returns 1
			% if the object is valid and 0 otherwise.
				b = 1; % for now, skip this
		end % validate()

		function bf = getbinaryfile(nsd_document_obj);
			% GETBINARYFILE - Get the binary file object for an NSD_DOCUMENT_OBJ
			%
				bf = [];
		end % getbinaryfileobj() 
	end % methods

	methods (Static)
		function s = readblankdefinition(jsonfilelocationstring, s)
			% READBLANKDEFINITION - read a blank JSON class definitions from a file location string
			%
			% S = READBLANKDEFINITION(JSONFILELOCATIONSTRING)
			%
			% Given a JSONFILELOCATIONSTRING, this function creates a blank document using the JSON definitions.
			%
			% A JSONFILELOCATIONSTRING can be:
			%	a) a url
			%	b) a filename (full path)
			%       c) a filename referenced with respect to $NSDDOCUMENTPATH
			%
			% See also: READJSONFILELOCATION
			%
				s_is_empty = 0;
				if nargin<2,
					s_is_empty = 1;
					s = emptystruct;
				end

				% Step 1): read the information we have here

				t = nsd_document.readjsonfilelocation(jsonfilelocationstring);
				j = jsondecode(t);

				% Step 2): integrate the new information into the document we are building onto 

				% Step 2a): Do we need to integrate this or do we already have same class and at least as good of a version?
				need_to_integrate = 1;
				if isfield(s,'document_superclass_data') & isfield(j,'document_class'),
					% dev note: assuming document_superclass_data reads correctly by matlab jsondecode as STRUCT 
					for k=1:numel(s.document_superclass_data)
						item = celloritem(s.document_superclass_data,k);
						if strcmp(j.document_class.class_name,item.class_name) & j.document_class.class_version<=item.class_version,
							need_to_integrate = 0;
							break;
						end 
					end
				end

				% Step 2b): Now integate if we need to

				if isfield(j,'document_superclass_data'),
					error(['Newly built object should not have field ''document_superclass_data''.']);
				end

				if need_to_integrate,
					if isempty(s),
						s(1).document_class = j.document_class;
						s(1).document_superclass_data = {};
					else,
						s(1).document_superclass_data{end+1} = j.document_class;
					end
					j_ = rmfield(j, 'document_class');
					s = structmerge(s, j_);
				else,
					return;
				end

				if isfield(j,'document_class'),
					if isfield(j.document_class,'superclasses'),
						for i=1:numel(j.document_class.superclasses),
							item = celloritem(j.document_class.superclasses, i, 1);
							s = nsd_document.readblankdefinition(item.definition, s);
						end
					end
				end

				if s_is_empty, % discard document_superclass_data
					s = rmfield(s,'document_superclass_data');
				end
		
		end % readblankdefinition() 

		function t = readjsonfilelocation(jsonfilelocationstring)
			% READJSONFILELOCATION - return the text from a json file location string in NSD
			%
			% T = READJSONFILELOCATION(JSONFILELOCATIONSTRING)
			%
			% A JSONFILELOCATIONSTRING can be:
			%      a) a url
			%      b) a filename (full path)
			%      c) a relative filename with respect to $NSDDOCUMENTPATH
			%      d) a filename referenced with respect to $NSDDOCUMENTPATH
			%
				nsd_globals;

				searchString = '$NSDDOCUMENTPATH';
				s = strfind(jsonfilelocationstring, searchString);
				if ~isempty(s), % insert the location
					filename = [nsddocumentpath filesep ...
						filesepconversion(jsonfilelocationstring(s+numel(searchString):end), nsd_filesep, filesep)];
				else,
					filename = jsonfilelocationstring;
					if ~exist(filename,'file'),
						filename2 = [nsddocumentpath filesep filename];
						if ~exist(filename2,'file'),
							error(['Cannot find file ' filename '.']);
						else,
							filename = filename2;
						end
					end
				end

				% filename could be url or filename

				if isurl(filename),
					t = urlread(filename);
				else,
					t = textfile2char(filename);
				end
		end

	end % methods Static
end % classdef

