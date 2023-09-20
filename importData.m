function cases = importData(fName)

% Function to import specific fields from unit record data on Covid-19 cases 
% Note: missing admission date data is replaced with report date (a message will be displayed about how many cases this applies to)
%
% USAGE: cases = importData(fName)
%
% INPUTS: fName - file name (.csv) to be read in
%
% OUTPUTS: cases - table of cases

% Set options for variable name, type, etc.
opts = detectImportOptions(fName, 'TextType', 'string');
opts.VariableNames{ismember(opts.VariableNames, 'ESR_AGE_YEARS')} = 'Age';
opts = setvartype(opts, {'STATUS', 'DHB', 'COVID_RELATED_HOSPITALISATION', 'Historical'}, {'categorical'});
opts = setvartype(opts, {'REPORT_DT', 'ONSET_DT_COALESCED'}, {'datetime'});
opts = setvartype(opts, {'Age', 'DAYS_IN_HOSP_COVID_RELATED'}, {'double'});       % NB Death field is 0 1, hence read as double
opts.SelectedVariableNames = {'STATUS', 'DHB', 'COVID_RELATED_HOSPITALISATION', 'Historical', 'REPORT_DT', 'ONSET_DT_COALESCED', 'ADMISSION_DT', 'Age', 'DAYS_IN_HOSP_COVID_RELATED' };

% Read data
cases = readtable(fName, opts);

% Convert some fields to datetime format which don't read in properly if you try to read them in directly as datetime :-( 
cases.ADMISSION_DT = datetime(string(cases.ADMISSION_DT), 'Inputformat', "yyyy-MM-dd");


% Print some summary statistics
nRows = height(cases);
fprintf('%i total cases\n', nRows);
fprintf('       %i (%.1f%%) cases with missing report date\n', sum(isnat(cases.REPORT_DT)), 100*sum(isnat(cases.REPORT_DT))/nRows);
fprintf('       %i (%.1f%%) cases with missing onset date\n', sum(isnat(cases.ONSET_DT_COALESCED)), 100*sum(isnat(cases.ONSET_DT_COALESCED))/nRows);
fprintf('       %i (%.1f%%) cases with missing age\n', sum(isnan(cases.Age)), 100*sum(isnan(cases.Age))/nRows  );



% Set missing admission dates to report date (and display warning)
ind = cases.COVID_RELATED_HOSPITALISATION == "1" & isnat(cases.ADMISSION_DT);
fprintf('Found %i/%i hospital cases with no admission date, using report date\n', sum(ind), sum(cases.COVID_RELATED_HOSPITALISATION == "1" ));
cases.ADMISSION_DT(ind) = cases.REPORT_DT(ind);

% Print statistics about missing data
ind = ~isnat(cases.ADMISSION_DT) & isnan(cases.DAYS_IN_HOSP_COVID_RELATED);
fprintf('    %i cases with admission but no DAYS_IN_HOSP_COVID_RELATED\n', sum(ind))


