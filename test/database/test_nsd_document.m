function test_nsd_document(dirname)
% TEST_NSD_DOCUMENT - Test the functionality of the NSD_DOCUMENT object and the NSD_EXPERIMENT database
%
%  TEST_NSD_DOCUMENT([DIRNAME])
%
%  Given a directory, this function tries to create some 
%  NSD_VARIABLE objects in the experiment DATABASE. The test function
%  removes them on completion.
%
%  If DIRNAME is not provided, the default directory
%  [NSDEXAMPLEEXPERPATH/exp1_eg] is used.
%
%

nsd_globals;

test_struct = 0;

if nargin<1,
	dirname = [nsdexampleexperpath filesep 'exp1_eg'];
end;

disp(['Creating a new experiment object in directory ' dirname '.']);
exp = nsd_experiment_dir('exp1',dirname);

 % if we ran the demo before, delete the entry

doc = exp.database.search({'subject.id','vhlab12345'});
if ~isempty(doc),
	for i=1:numel(doc),
		exp.database_rm(doc_unique_id(doc{i}));
	end;
end;

doc = exp.newdocument('nsd_document_subjectmeasurement',...
	'nsd_document.name','Animal statistics',...
	'subject.id','vhlab12345', ...
	'subject.species','Mus musculus',...
	'subjectmeasurement.measurement','age',...
	'subjectmeasurement.value',30,...
	'subjectmeasurement.datestamp','2017-03-17T19:53:57.066Z'...
	);

 % add it here
exp.database_add(doc);

  % store some data in the binary portion of the file
binarydoc = exp.database.openbinarydoc(doc);
disp(['Storing ' mat2str(0:9) '...'])
binarydoc.fwrite(char([0:9]),'char');
binarydoc = exp.database.closebinarydoc(binarydoc);

 % now read the object back

doc = exp.database.search({'subject.id','vhlab12345'});
if numel(doc)~=1,
	error(['Found more than one document with subject.id vhlab12345; this means there is a database problem.']);
end;
doc = doc{1}, % should be only one match

 % read the binary data
binarydoc = exp.database.openbinarydoc(doc);
disp('About to read stored data: ');
data = double(binarydoc.fread(10,'char'))',
binarydoc = exp.database.closebinarydoc(binarydoc);

% remove the document

doc = exp.database.search({'subject.id','vhlab12345'});
if ~isempty(doc),
	for i=1:numel(doc),
		exp.database_rm(doc_unique_id(doc{i}));
	end;
end;


