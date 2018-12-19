classdef  nsd_matlabdumbjsondb < nsd_database

	properties
		db		% dumbjsondb object
	end

	methods

		function nsd_matlabdumbjsondb_obj = nsd_matlabdumbjsondb(varargin)
		% NSD_MATLABDUMBJSONDB make a new NSD_MATLABDUMBJSONDB object
		% 
		% NSD_MATLABDUMBJSONDB_OBJ = NSD_MATLABDUMBJSONDB(PATH, EXPERIMENT_UNIQUE_REFERENCE, COMMAND, ...)
		%
		% Creates a new NSD_MATLABDUMBJSONDB object.
		%
		% COMMAND can either be 'Load' or 'New'. The second argument
		% should be the full pathname of the location where the files
		% should be stored on disk.
		%
		% See also: DUMBJSONDB, DUMBJSONDB/DUMBJSONDB
			nsd_matlabdumbjsondb_obj = nsd_matlabdumbjsondb_obj@nsd_database(varargin{:});
			nsd_matlabdumbjsondb_obj.db = dumbjsondb(varargin{3:end},...
				'dirname','.dumbjsondb','unique_object_id_field','nsd_document.document_unique_reference');
		end; % nsd_matlabdumbjsondb()

	end 

	methods (Access=protected),

		function nsd_matlabdumbjsondb_obj = do_add(nsd_matlabdumbjsondb_obj, nsd_document_obj, add_parameters)
			namevaluepairs = {};
			fn = fieldnames(add_parameters);
			for i=1:numel(fn), 
				if strcmpi(fn{i},'Update'),
					namevaluepairs{end+1} = 'Overwrite';
					namevaluepairs{end+1} = getfield(add_parameters,fn{i});
				end;
			end;
			
			nsd_matlabdumbjsondb_obj.db = nsd_matlabdumbjsondb_obj.db.add(nsd_document_obj.document_properties, namevaluepairs{:});
		end; % do_add

		function [nsd_document_obj, version] = do_read(nsd_matlabdumbjsondb_obj, nsd_document_id, version);
			if nargin<3,
				version = [];
			end;
			[doc, version] = nsd_matlabdumbjsondb_obj.db.read(nsd_document_id, version);
			nsd_document_obj = nsd_document(doc);
		end; % do_read

		function nsd_matlabdumbjsondb_obj = do_remove(nsd_matlabdumbjsondb_obj, nsd_document_id, versions)
			if nargin<3,
				versions = [];
			end;
			nsd_matlabdumbjsondb_obj = nsd_matlabdumbjsondb_obj.db.read(nsd_document_id, versions);
		end; % do_remove

		function [nsd_document_objs,doc_versions] = do_search(nsd_matlabdumbjsondb_obj, searchoptions, searchparams)
			nsd_document_objs = {};
			[docs,doc_versions] = nsd_matlabdumbjsondb_obj.db.search(searchoptions, searchparams);
			for i=1:numel(docs),
				nsd_document_objs{i} = nsd_document(docs{i});
			end;
		end; % do_search()

		function [nsd_binarydoc_obj] = do_binarydoc(nsd_matlabdumbjsondb_obj, nsd_document_id, version)
			nsd_binarydoc_obj = [];
			fid = nsd_matlabdumbjsondb_obj.openbinaryfile(nsd_document_id, version);
			if fid>0,
				[filename,permission,machineformat,encoding] = fopen(fid);
				nsd_binarydoc_obj = nsd_binarydoc_matfid('fid',fid,'fullpathfilename',filename,...
					'machineformat',machineformat,'permission',permission);
			end
		end; % do_binarydoc()

	end;

end
