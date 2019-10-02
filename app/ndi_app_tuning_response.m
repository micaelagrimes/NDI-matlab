classdef ndi_app_tuning_response < ndi_app

	properties (SetAccess=protected,GetAccess=public)

	end % properties

	methods

		function ndi_app_tuning_response_obj = ndi_app_tuning_response(varargin)
			% NDI_APP_TUNING_RESPONSE - an app to decode stimulus information from NDI_PROBE_STIMULUS objects
			%
			% NDI_APP_TUNING_RESPONSE_OBJ = NDI_APP_TUNING_RESPONSE(EXPERIMENT)
			%
			% Creates a new NDI_APP_TUNING_RESPONSE object that can operate on
			% NDI_EXPERIMENTS. The app is named 'ndi_app_stimulus_response'.
			%
				experiment = [];
				name = 'ndi_app_tuning_response';
				if numel(varargin)>0,
					experiment = varargin{1};
				end
				ndi_app_tuning_response_obj = ndi_app_tuning_response_obj@ndi_app(experiment, name);

		end % ndi_app_tuning_response() creator

		function [newdocs, responses] = stimulus_responses(ndi_app_tuning_response_obj, ndi_probe_stim, ndi_timeseries_obj, reset)
			% PARSE_STIMULI - write stimulus records for all stimulus epochs of an NDI_PROBE stimulus probe
			%
			% [NEWDOCS, EXISITINGDOCS] = STIMULUS_RESPONSES(NDI_APP_TUNING_RESPONSE_OBJ, NDI_PROBE_STIM, NDI_TIMESERIES_OBJ, [RESET])
			%
			% Examines a the NDI_EXPERIMENT associated with NDI_APP_TUNING_RESPONSE_OBJ and the stimulus
			% probe NDI_STIM_PROBE, and creates documents of type NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE
			% for all stimulus epochs.
			%
			% If NDI_DOCUMENT_STIMULUS and NDI_DOCUMENT_STIMULUS_TUNINGCURVE documents already exist for a given
			% stimulus run, then they are returned in EXISTINGDOCS. Any new documents are returned in NEWDOCS.
			%
			% If the input argument RESET is given and is 1, then all existing documents for this probe are
			% removed and all documents are recalculated. The default for RESET is 0 (if it is not provided).
			%
			% Note that this function DOES add the new documents to the database.
			%
				E = ndi_app_tuning_response_obj.experiment;

				newdocs = {};
				responses = {};

				% find all stimulus records from the stimulus probe
				sq_probe = ndi_query(ndi_probe_stim.searchquery());
				sq_e = ndi_query(E.searchquery());
				sq_stim = ndi_query('','isa','ndi_document_stimulus_presentation.json',''); % presentation
				sq_tune = ndi_query('','isa','ndi_document_stimulus_tuningcurve.json','');
				doc_stim = E.database_search(sq_stim&sq_e&sq_probe);
				doc_tune = E.database_search(sq_tune&sq_e&sq_probe);

				ndi_ts_epochs = {};

				% find all the epochs of overlap between stimulus probe and ndi_timeseries_obj

				for i=1:numel(doc_stim),
					% ASSUMPTION: each stimulus probe epoch will overlap a single ndi_timeseries_obj epoch
					%   therefore, we can use the first stimulus as a proxy for them all
					if numel(doc_stim{i}.document_properties.presentation_time)>0, % make sure there is at least 1 stimulus 
						stim_timeref = ndi_timereference(ndi_probe_stim, ...
							ndi_clocktype(doc_stim{i}.document_properties.presentation_time(1).clocktype), ...
							doc_stim{i}.document_properties.epochid, doc_stim{i}.document_properties.presentation_time(1).onset);
						[ts_epoch_t0_out, ts_epoch_timeref, msg] = E.syncgraph.time_convert(stim_timeref,...
							0, ndi_timeseries_obj, ndi_clocktype('dev_local_time')); % time is 0 because stim_timeref is relative to 1st stim
						if ~isempty(ts_epoch_t0_out),
							ndi_ts_epochs{i} = ts_epoch_timeref.epoch;
						else,
							ndi_ts_epochs{i} = '';
						end;
					end;
				end;

				for i=1:numel(doc_stim),
					if ~isempty(ndi_ts_epochs{i}),
						ctrl_search = ndi_query('control_stim_ids.stimulus_presentation_doc_unique_id','exact_string',doc_stim{i}.doc_unique_id(),'');
						control_stim_doc = E.database_search(ctrl_search);
						for j=1:numel(control_stim_doc),
							% okay, now how to analyze these stims?
							% 
							% want to calculate F0, F1, F2
							% want to do this for regularly sampled and timestamp type data
							if 0,
								ndi_ts_epochs{i}
								doc_stim{i}.document_properties
								doc_stim{i}.document_properties.stimuli(1).parameters
								doc_stim{i}.document_properties.presentation_order
								doc_stim{i}.document_properties.presentation_time
								control_stim_doc{j}.document_properties.control_stim_ids
								control_stim_doc{j}.document_properties.control_stim_ids.control_stim_ids
							end;
							ndi_timeseries_obj,
							ndi_app_tuning_response_obj.compute_stimulus_response_scalar(ndi_probe_stim, ndi_timeseries_obj, doc_stim{i}, control_stim_doc{j});
						end;

					end
				end
		end % 

		function response_doc = compute_stimulus_response_scalar(ndi_app_tuning_response_obj, ndi_stim_obj, ndi_timeseries_obj, stim_doc, control_doc, varargin)
			% COMPUTE_STIMULUS_RESPONSES - compute responses to a stimulus set
			%
			% RESPONSE_DOC = COMPUTE_STIMULUS_RESPONSE_SCALAR(NDI_APP_TUNING_RESPONSE_OBJ, NDI_TIMESERIES_OBJ, STIM_DOC, ...)
			%
			% Given an NDI_TIMESERIES_OBJ, a STIM_DOC (an NDI_DOCUMENT of class 'ndi_document_stimulus_presentation'), and a
			% CONTROL_DOC (an NDI_DOCUMENT of class 'ndi_document_control_stimulus_ids'), this
			% function computes the stimulus responses of NDI_TIMESERIES_OBJ and stores the results as an
			% NDI_DOCUMENT of class 'ndi_stimulus_response_scalar'. In this app, by default, mean responses and responses at the
			% fundamental stimulus frequency are calculated. Note that this function may generate multiple documents (for mean responses, F1, F2).
			%
			% Note that we recommend making a new app subclass if one wants to write additional classes of analysis procedures.
			%
			% This function also takes name/value pairs that alter the behavior:
			% Parameter (default)                  | Description
			% ---------------------------------------------------------------------------------
			% temporalfreqfunc                     |
			%   ('ndi_stimulustemporalfrequency')  |
			% freq_response ([])                   | Frequency response to measure. If empty, then the function is 
			%                                      |   called 3 times with values 0, 1, and 2 times the fundamental frequency.
			% prestimulus_time ([])                | Calculate a baseline using a certain amount of TIMESERIES signal during
                        %                                      |     the pre-stimulus time given here
			% prestimulus_normalization ([])       | Normalize the stimulus response based on the prestimulus measurement.
			%                                      | [] or 0) No normalization
			%                                      |       1) Subtract: Response := Response - PrestimResponse
			%                                      |       2) Fractional change Response:= ((Response-PrestimResponse)/PrestimResponse)
			%                                      |       3) Divide: Response:= Response ./ PreStimResponse
			% isspike (0)                          | 0/1 Is the signal a spike process? If so, timestamps correspond to spike events.
			% spiketrain_dt (0.001)                | Resolution to use for spike train reconstruction if computing Fourier transform
			%
			%
				temporalfreqfunc = 'ndi_stimulustemporalfrequency';
				freq_response = [];
				prestimulus_time = [];
				prestimulus_normalization = [];
				isspike = 0;
				spiketrain_dt = 0.001;

				if ~isempty(intersect(fieldnames(ndi_timeseries_obj),'type')),
					if strcmpi(ndi_timeseries_obj.type,'spikes'),
						isspike = 1;
					end;
				end;

				assign(varargin{:});

				response_doc = {};

				E = ndi_app_tuning_response_obj.experiment;
				gapp = ndi_app_markgarbage(E);

				if isempty(freq_response),
					% do we have any stims that we know have a fundamental stimulus frequency?
					gotone = 0;
					for j=1:numel(stim_doc.document_properties.stimuli),
						eval(['freq_multi_here = ' temporalfreqfunc '(stim_doc.document_properties.stimuli(j).parameters);']);
						if ~isempty(freq_multi_here),
							gotone = 1; 
							break;
						end;
					end;
					if gotone,
						freq_response_commands = [0 1 2];
					else,
						freq_response_commands = 0;
					end;
				else,
					freq_response_commands = freq_response;
				end;

				% build up search for existing parameter documents
				q_doc = ndi_query('','isa','ndi_document_stimulus_response_scalar_parameters_basic.json','');
				q_rdoc = ndi_query('','isa','ndi_document_stimulus_response_scalar.json','');
				q_r_stimdoc = ndi_query('stimulus_document_identifier','exact_string',stim_doc.doc_unique_id(),'');
				q_r_stimcontroldoc = ndi_query('stimulus_control_document_identifier','exact_string',control_doc.doc_unique_id(),'');
				q_e = ndi_query(E.searchquery());
				q_match{1} = ndi_query('stimulus_response_scalar_parameters_basic.temporalfreqfunc','exact_string',temporalfreqfunc,'');
				q_match{2} = ndi_query('stimulus_response_scalar_parameters_basic.prestimulus_time','exact_number',prestimulus_time,'');
				q_match{3} = ndi_query('stimulus_response_scalar_parameters_basic.prestimulus_normalization','exact_number',prestimulus_normalization,'');
				q_match{4} = ndi_query('stimulus_response_scalar_parameters_basic.isspike','exact_number',isspike,'');
				q_match{5} = ndi_query('stimulus_response_scalar_parameters_basic.spiketrain_dt','exact_number',spiketrain_dt,'');
				q_matchtot = q_match{1};
				for j=2:numel(q_match),
					q_matchtot = q_matchtot & q_match{j};
				end;
				q_matchtot = q_e & q_doc & q_matchtot;

				% load the data, get the stimulus times				

				stim_stim_onsetoffsetid=[colvec([stim_doc.document_properties.presentation_time.onset]) ...
						colvec([stim_doc.document_properties.presentation_time.offset]) ...
						colvec([stim_doc.document_properties.presentation_order])];

				stim_timeref = ndi_timereference(ndi_stim_obj, ...
					ndi_clocktype(stim_doc.document_properties.presentation_time(1).clocktype), ...
					stim_doc.document_properties.epochid, 0);

				[ts_epoch_t0_out, ts_epoch_timeref, msg] = E.syncgraph.time_convert(stim_timeref,...
					colvec(stim_stim_onsetoffsetid(:,[1 2])), ndi_timeseries_obj, ndi_clocktype('dev_local_time'));

				ts_stim_onsetoffsetid = [reshape(ts_epoch_t0_out,numel(stim_doc.document_properties.presentation_order),2) stim_stim_onsetoffsetid(:,3)];

				[data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, ts_epoch_timeref.epoch, 0, 1);

				vi = gapp.loadvalidinterval(ndi_timeseries_obj);
				interval = gapp.identifyvalidintervals(ndi_timeseries_obj,timeref,0,Inf);

				[data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, ts_epoch_timeref.epoch, interval(1,1), interval(1,2));

				for f=1:numel(freq_response_commands),

					freq_response = freq_response_commands(f);

					if freq_response==0,
						response_type = 'mean';
					else,
						response_type = ['F' int2str(freq_response)];
					end;

					% step 1, build the parameter document, if necessary; if we can find an example, use it
					q_matchhere = ndi_query('stimulus_response_scalar_parameters_basic.freq_response','exact_number',freq_response,'');

					param_doc = E.database_search(q_matchtot&q_matchhere);

					if isempty(param_doc),
						% make one
						stimulus_response_scalar_parameters_basic = var2struct('temporalfreqfunc','freq_response','prestimulus_time','prestimulus_normalization',...
							'isspike','spiketrain_dt');
						param_doc = ndi_document('stimulus/ndi_document_stimulus_response_scalar_parameters_basic.json',...
							'stimulus_response_scalar_parameters_basic', stimulus_response_scalar_parameters_basic') + E.newdocument();
						E.database_add(param_doc);
						param_doc = {param_doc};
					end;

					% look for response docs

					rdoc = E.database_search(q_e&q_rdoc&q_r_stimdoc&q_r_stimcontroldoc&...
						ndi_query('stimulus_response_scalar_parameters_identifier','exact_string',param_doc{1}.doc_unique_id(),''));

					E.database_rm(rdoc);

					controlstimids = control_doc.document_properties.control_stim_ids.control_stim_ids;
					freq_mult = [];
					for j=1:numel(stim_doc.document_properties.stimuli),
						eval(['freq_multi_here = ' temporalfreqfunc '(stim_doc.document_properties.stimuli(j).parameters);']);
						if ~isempty(freq_multi_here),
							freq_mult(j) = freq_multi_here;
						else,
							freq_mult(j) = 0;
						end;

					end;

					response = stimulus_response_scalar(data, t_raw, ts_stim_onsetoffsetid, 'control_stimid', controlstimids,...
						'freq_response', freq_response*freq_mult, 'prestimulus_time',prestimulus_time,'prestimulus_normalization',prestimulus_normalization,...
						'isspike',isspike,'spiketrain_dt',spiketrain_dt);

					response_structure = struct('stimulus_identifier',rowvec(ts_stim_onsetoffsetid(:,3)),...
							'response_real', rowvec(real([response.response])), 'response_imaginary', rowvec(imag([response.response])), ...
							'control_response_real', rowvec(real([response.control_response])), ...
							'control_response_imaginary',rowvec(imag([response.control_response])));

					stimulus_response_scalar_struct = struct('response_type', response_type, 'responses',response_structure,...
						'stimulus_response_scalar_parameters_identifier',param_doc{1}.doc_unique_id());

					stimulus_response_struct = struct('stimulator_unique_reference','',...
						'stimulus_presentation_document_identifier', stim_doc.doc_unique_id(), ...
						'stimulus_control_document_identifier', control_doc.doc_unique_id());

					response_doc{end+1} = ndi_document('stimulus/ndi_document_stimulus_response_scalar','stimulus_response_scalar',stimulus_response_scalar_struct,...
							'stimulus_response', stimulus_response_struct,'thingreference.thing_unique_id',ndi_timeseries_obj.doc_unique_id())+E.newdocument();
					E.database_add(response_doc{end});
				end;
		end; % compute_stimulus_response_scalar()

		function cs_doc = label_control_stimuli(ndi_app_tuning_response_obj, stimulus_probe_obj, reset, varargin)
			% LABEL_CONTROL_STIMULI - label control stimuli for all stimulus presentation documents for a given stimulator
			%
			% CS_DOC = LABEL_CONTROL_STIMULI(NDI_APP_TUNING_RESPONSE_OBJ, STIMULUS_PROBE_OBJ, RESET, ...)
			%
			% Thus function will look for all 'ndi_document_stimulus_presentation' documents for STIMULUS_PROBE_OBJ,
			% compute the corresponding control stimuli, and save them as an 'ndi_document_control_stimulus_ids' 
			% document that is also returned as a cell list in CS_DOC.
			%
			% If RESET is 1, then any existing documents of this type are first removed. If RESET is not provided or is
			% empty, then it is taken to be 0.
			%
			% The method of finding the control stimulus can be provided by providing extra name/value pairs.
			% See NDI_APP_TUNING_RESPONSE/CONTROL_STIMULUS for parameters.
			% 
				if nargin<3,
					reset = 0;
				end;

				sq_probe = ndi_query(stimulus_probe_obj);
				sq_stim = ndi_query('','isa','ndi_document_stimulus_presentation.json','');

				if reset,
					sq_csi = ndi_query('','isa','ndi_document_control_stimulus_ids.json','');
					old_cs_doc = ndi_app_tuning_response_obj.experiment.database_search(sq_csi&sq_probe);
					ndi_app_tuning_response_obj.experiment.database_rm(old_cs_doc);
				end;

				stimdoc = ndi_app_tuning_response_obj.experiment.database_search(sq_stim&sq_probe);

				cs_doc = {};

				for i=1:numel(stimdoc),
					[cs_ids,cs_doc_here] = ndi_app_tuning_response_obj.control_stimulus(stimdoc{i},varargin{:});
					cs_doc{end+1} = cs_doc_here;
				end;
		end;
		
		function [cs_ids, cs_doc] = control_stimulus(ndi_app_tuning_response_obj, stim_doc, varargin)
			% CONTROL_STIMULUS - determine the control stimulus ID for each stimulus in a stimulus set
			%
			% [CS_IDS, CS_DOC] = CONTROL_STIMULUS(NDI_APP_TUNING_RESPONSE_OBJ, STIM_DOC, ...)
			%
			% For a given set of stimuli described in NDI_DOCUMENT of type 'ndi_document_stimulus',
			% this function returns the control stimulus ID for each stimulus in the vector CS_IDS 
			% and a corresponding NDI_DOCUMENT of type ndi_document_control_stimulus_ids that describes this relationship.
			%
			%
			% This function accepts parameters in the form of NAME/VALUE pairs:
			% Parameter (default)              | Description
			% ------------------------------------------------------------------------
			% control_stim_method              | The method to be used to find the control stimulu for
			%  ('psuedorandom')                |    each stimulus:
			%                       -----------|
			%                       |   pseudorandom: Find the stimulus with a parameter
			%                       |      'controlid' that is in the same pseudorandom trial. In the
			%                       |      event that there is no match that divides evenly into 
			%                       |      complete repetitions of the stimulus set, then the
			%                       |      closest stimulus with field 'controlid' is chosen.
			%                       |      
			%                       |      
			%                       -----------|
			% controlid ('isblank')            | For some methods, the parameter that defines whether
			%                                  |    a stimulus is a 'control' stimulus or not.
			% controlid_value (1)              | For some methods, the parameter value of 'controlid' that
			%                                  |    defines whether a stimulus is a control stimulus or not.

				control_stim_method = 'psuedorandom';
				controlid = 'isblank';
				controlid_value = 1;
			
				assign(varargin{:});

				switch (lower(control_stim_method)),
					case 'psuedorandom'
						control_stim_id_method.method = control_stim_method;
						control_stim_id_method.controlid = controlid;
						control_stim_id_method.controlid_value = controlid_value;
		
						controlstimid = [];
						for n=1:numel(stim_doc.document_properties.stimuli),
							if fieldsearch(stim_doc.document_properties.stimuli(n).parameters, ...
								struct('field',controlid,'operation','exact_number','param1',controlid_value,'param2',[])),
								controlstimid(end+1) = n;
							end;
						end;
						
						% what if we have more than one? bail out for now

						if numel(controlstimid)>1,
							error(['Do not know what to do with more than one control stimulus type.']);
						end;

						% if number of control stimuli is 0, that's okay, just give values of NaN

						stimids = stim_doc.document_properties.presentation_order;

						[reps,isregular] = stimids2reps(stimids,numel(stim_doc.document_properties.stimuli));

						control_stim_indexes = [];
						if ~isempty(controlstimid),
							control_stim_indexes = find(stimids==controlstimid);
						end;

						if isempty(control_stim_indexes),
							cs_ids = nan(size(stimids));
						else,
							if isregular,
								if numel(unique(reps))>numel(control_stim_indexes),
									control_stim_indexes(end+1) = control_stim_indexes(end); % let previous control stim stand in for incomplete
								end;
								cs_ids = control_stim_indexes(reps);
							else,
								cs_ids = [];
								% slow
								presentation_onsets = [stim_doc.document_properties.presentation_time.onset];
								for n=1:numel(stimids),
									i=findclosest(presentation_onsets(control_stim_indexes), presentation_onsets(n));
									cs_ids(n) = control_stim_indexes(i);
								end;
							end;
						end;
					otherwise,
						error(['Unknown control stimulus method ' control_stim_method '.']);

				end; % switch

				% now we have cs_ids for each stimulus, so make the document

				control_stim_ids_struct = struct('stimulus_presentation_doc_unique_id', stim_doc.doc_unique_id(), 'control_stim_ids', cs_ids);

				cs_doc = ndi_document('stimulus/ndi_document_control_stimulus_ids','control_stim_ids',control_stim_ids_struct, ...
					'control_stim_id_method',control_stim_id_method) + ndi_app_tuning_response_obj.newdocument();

				ndi_app_tuning_response_obj.experiment.database_add(cs_doc);

		end; % control_stimulus()

		function other  = analyze_tuning_responses(ndi_app_tuning_response_obj, ndi_timeseries_obj, stim_doc, varargin)
			% COMPUTE_STIMULUS_RESPONSE_SUMMARY - compute responses to a stimulus set
			%
			% DOC = COMPUTE_STIMULUS_RESPONSE_SUMMARY(NDI_APP_STIMULUS_RESPONSE_APP, NDI_PROBE_STIM, NDI_TIMESERIES_OBJ, STIM_DOC, TIMEREF, T0, T1, ...)
			%
			% Note: Uses the app NDI_APP_MARKGARBAGE to limit analysis to intervals that have been
			% marked as valid or have not been marked invalid.
			%
			%
			% This function also takes name/value pairs that alter the behavior:
			% Parameter (default)             | Description
			% ---------------------------------------------------------------------------------
			% independent_axis_units ('')     | If empty, the program attempts to determine the
			%                                 |   axis units by determining what varies across the
			%                                 |   stimulus parameters.
			% independent_axis_label ('')     | The label to use by a plotting program for the independent
			%                                 |   variable
			% independent_axis_parameter ('') | The parameter to read from the stimulus in order
			%                                 |   to obtain the independent_axis_values.
			% response_units ('')             | Response units; if empty, attempts to read from probe
			% response_label ('')             | Label for the responses for a plotting program
			%                                 |
			% blank_stimid ([])               | Pass the stimulus id numbers of any 'blank' (control)
			%                                 |   stimuli. If empty, then the program will look for 'isblank'
			%                                 |   fields in the parameters.
			% freq_response_parameter (0)     | The parameter of each stimulus to examine for frequency response.
			%                                 |   If 0, then the mean response is used.
			% freq_response_multiplier (0)    | The multipier to use with the freq_response_parameter value. For example,
			%                                 |   pass '1' to compute the F1 component (the response at the freq_response_parameter
			%                                 |   frequency).
			% prestimulus_time ([])           | If a baseline per stimulus is to be computed, it can be passed here (time in seconds)
			% prestimulus_normalization ([])  | Normalize the stimulus response based on the prestimulus measurement.
			%                                 | [] or 0) No normalization
			%                                 |       1) Subtract: Response := Response - PrestimResponse
			%                                 |       2) Fractional change Response:= ((Response-PrestimResponse)/PrestimResponse)
			%                                 |       3) Divide: Response:= Response ./ PreStimResponse
			%
				independent_axis_units = '';
				independent_axis_label = '';
				independent_axis_parameter = '';
				response_units = '';
				response_label = '';

				blank_stimid = [];

				freq_response_parameter = 0;
				freq_response_multiplier = 0;

				prestimulus_time = [];
				prestimulus_normalization = [];

				assign(varargin{:});

				[data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, timeref, t0, t0);

				gapp = ndi_app_markgarbage(ndi_app_stimulus_response_obj.experiment);
				vi = gapp.loadvalidinterval(sharpprobe);
				interval = gapp.identifyvalidintervals(ndi_timeseries_obj,timeref,t0,t1)

				[ds, ts, timeref_]=ndi_probe_stim.readtimeseries(timeref,interval(1,1),interval(1,2));
				[data,t_raw,timeref] = readtimeseries(ndi_timeseries_obj, timeref, interval(1,1), interval(1,2));

				stim_onsetoffsetid = [ts.stimon ts.stimoff ds.stimid];

				if isempty(blank_stimid),
					isblank = structfindfield(ds.parameters,'isblank',1);
					notblank = setdiff(1:numel(ds.parameters),isblank);
					blank_stimid = isblank;
				end;

				% now get frequencies in order

				if isempty(freq_response_parameter),
					freq_response_parameter = 0;
					freq_response = 0;
				elseif isnumeric(freq_response_parameter),
					freq_response = freq_response_parameter;
				elseif ischar(freq_response_parameter),
					freq_response = [];
					for i=1:numel(ds.parameters),
						if isfield(ds.parameters{i},freq_response_parameter),
							freq_response(i) = getfield(ds.parameters{i},freq_response_parameter) * freq_response_multiplier;
						else,
							freq_response(i) = 0;
						end
					end
				end

				nvp = str2namevaluepair(var2struct('freq_response',blank_stimid','prestimulus_time','prestimulus_normalization'));

				response = stimulus_response_summary(data, t_raw, stim_onsetoffsetid, 'freq_response', freq_response, nvp{:});

				% now need to convert response to document

				% need to read independent_axis values

				independent_axis_values = [];

				if isempty(independent_axis_parameter),
					independent_axis_values = response.stimid;
				else,
					for i=1:numel(response.stimid),
						if isfield(ds.parameters{response.stimid(i)}),
							independent_axis_values(i) = getfield(ds.parameters{response.stimid(i)});
						else,
							independent_axis_values(i) = NaN;
						end
					end
				end

				independent_axis_units = '';
				independent_axis_label = '';
				independent_axis_parameter = '';
				response_units = '';
				response_label = '';

				doc = ndi_app_stimulus_response_obj.experiment.newdocument('data/stimulus_response_summary', ...
						'stimulus_response_summary.independent_axis_units', independent_axis_units, ...
						'stimulus_response_summary.independent_axis_label', independent.axis_label, ...
						'stimulus_response_summary.independent_axis_parameter', independent_axis_parameter, ...
						'stimulus_response_summary.response_units', response_units, ...
						'stimulus_response_summary.response_label', response_label, ...
						'stimulus_response_summary.independent_axis_values', '', ...
						'stimulus_response_summary.mean_responses', responses.mean_responses, ...
						'stimulus_response_summary.stddev_responses', responses.stddev_responses, ...
						'stimulus_response_summary.stderr_responses', responses.stderr_responses, ...
						'stimulus_response_summary.individual_responses', responses.individual_responses, ...
						'stimulus_response_summary.blank_response.mean_responses', responses.blank_mean, ...
						'stimulus_response_summary.blank_response.stddev_responses', responses.blank_stddev, ...
						'stimulus_response_summary.blank_response.stderr_responses', responses.blank_stderr, ...
						'stimulus_response_summary.blank_response.individual_responses', responses.blank_individual_responses ...
						) + ndi_app_stimulus_response_obj.newdocument();

		end; % analyze_1d_tuning_curve

	end; % methods

end % ndi_app_stimulus_response


