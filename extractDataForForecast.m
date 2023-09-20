clear 
close all

% Script to import case data from file TPM_comm_cases_info_YYYY-MM-DD.csv with date stamp specified by the dateLbl variable defined below
% Data will be saved in folder /data/ in aggregated form, suitable for reading into the forecasting model 


% Date stamp on file TPM_comm_cases_info_YYYY-MM-DD.csv to be read in
% Single date:
readDate = datetime(2023, 9, 18);
% Or range of weekly dates 
%readDate = datetime(2022, 10, 3):7:datetime(2023, 7, 24);

% Folder in which TPM_comm_cases_info_YYYY-MM-DD.csv is stored
readFolder = "C:/Users/mpl31/Dropbox (UC Enterprise)/covid19data/ESR Data/MOH";

% Folder in which to save aggregated data extract to be read into forecasting model
saveFolder = 'data';

% Start date for analysis  25JAN2022
date0 = datetime(2022, 1, 25);      









% List of area names for which data will be aggregated: "National", four "regions", plus a list of individual DHB names reflecting the DHBs in the input data
areaNames = categorical( ["National", "Northern_region", "Midland_region", "Central_region", "Southern_region", "Northland", "Waitemata", "Auckland", "Counties Manukau", "Waikato", "Bay of Plenty", "Lakes", "Tairawhiti", "Taranaki", "Whanganui", "Hawke's Bay", "Wairarapa", "Capital & Coast/Hutt", "MidCentral", "Nelson Marlborough", "Canterbury/West Coast", "South Canterbury", "Southern"]);
nAreas = length(areaNames);


% Data window and min/max for onset to report distribution
OtoR_wStart = 70;       % Extracts data between wStart and wEnd days prior to current date
OtoR_wEnd = 0;
OtoRMin = -7;
OtoRMax = 14;

% Data window and min/max for report to admission distribution
RtoA_wStart = 126;
RtoA_wEnd = 56;
RtoAMin = -7;       % this excludes a significant proportion but it's likely these were initially admitted for non-covid reasons so seems reasonable to exclude highly negative RtoA (there are also some around -30, etc. which may be date transcription errors)
RtoAMax = 14;

% Data window and max for LOS
LOS_wStart = 126;
LOS_wEnd = 56;
LOSmax = 56;

meta = getMetaData();


% Age bands
ageBreaks = 0:10:90;
nAges = length(ageBreaks);

% Define "extended" arrays for use in histcounts
ageBreaks_ext = [ageBreaks, 130];

% Define arrays and "extended" arrays for OtoR, RtoA and age-dependent LOS
OtoR_array = OtoRMin:OtoRMax;
OtoR_array_ext = [OtoR_array, max(OtoR_array)+1];
RtoA_array = RtoAMin:RtoAMax;
RtoA_array_ext = [RtoA_array, max(RtoA_array)+1];
LOS_array = 0:1:LOSmax;
LOS_array_ext = [LOS_array, max(LOS_array)+1];


% Go through each specified data read-in date, extract data and save results
for iDt = 1:length(readDate)
    % Load case linelist data 
    dateLbl = datetime(readDate(iDt), 'format', 'yyyy-MM-dd');
    % Datafile to read
    fName = sprintf('%s/TPM_comm_cases_info_%s.csv', readFolder, dateLbl);

    if exist(fName, 'file')
        fprintf('Reading file %s\n', fName)
        cases = importData(fName);
    
        % Keep confirmed and probable cases only, and exclude any historical cases or cases before specified start date:
        statusCats = categorical(["Confirmed", "Probable"]);
        keepFlag = cases.REPORT_DT >= date0 & ismember(cases.STATUS, statusCats) & cases.Historical ~= "Yes"  ;
        cases = cases(keepFlag, :);
        [nRows, ~] = size(cases);
    
        % Create vector of dates
        t = date0:readDate(iDt)-1;
        % Extended vector to use as bin edges in calls to histcounts:
        tExt = [t, t(end)+0.999];
        
        % Define variables for totals each day and split by age group
        nCasesByAge = zeros(nAges, length(t));          % reported cases
        nHospByAge_DOR = zeros(nAges, length(t));       % admissions by date of report
        nHospByAge_DOA = zeros(nAges, length(t));       % admissions by date of admission
        nDiscByAge = zeros(nAges, length(t));           % discharges by date of discharge
        LOS_freq = zeros(nAges, length(LOS_array));     % length of stay frequency
        nExcl_LOS = zeros(nAges, 1);                    % number not counted in LOS frequency (e.g. due to LOS outside range or missing)
        nOver_LOS = zeros(nAges, 1);                    % number not counted in LOS frequency becausew their LOS is above the specified maximum 
    
        % Cycle through area names
        epiDataPart = [];
        for iArea = 1:nAreas
            if areaNames(iArea) == "National"                   % include all cases nationally (may include some with missing DHB data or DHB not in the list)
                DHBflag = ones(height(cases), 1);               
            elseif contains( string(areaNames(iArea)), "region")         % for "region" areas, aggregate across the relevant DHBs 
                DHBlist = meta.regionLookup.DHB(meta.regionLookup.region == areaNames(iArea)); 
                DHBflag = ismember(cases.DHB, DHBlist);
            else
                DHBflag = cases.DHB == areaNames(iArea);         % only include cases from individual DHB specified
            end
            if sum(DHBflag) == 0
                fprintf('Warning: no cases found for areaName %s\n', areaNames(iArea))
            end
            % Cycle through age groups to get case data
            for iAge = 1:nAges
                ageFlag = cases.Age >= ageBreaks_ext(iAge) & cases.Age < ageBreaks_ext(iAge+1);
                nCasesByAge(iAge, :) = histcounts(cases.REPORT_DT(ageFlag & DHBflag), tExt);
                nHospByAge_DOR(iAge, :) = histcounts(cases.REPORT_DT(ageFlag & DHBflag & cases.COVID_RELATED_HOSPITALISATION == "1"), tExt);
                nHospByAge_DOA(iAge, :) = histcounts(cases.ADMISSION_DT(ageFlag & DHBflag & cases.COVID_RELATED_HOSPITALISATION == "1"), tExt);
                % Note: -1 from discharge date in the following because for someone admitted & discharged on same day DAYS_IN_HOSP_COVID_RELATED is recored as 1 
                nDiscByAge(iAge, :) = histcounts(cases.ADMISSION_DT(ageFlag & DHBflag & cases.COVID_RELATED_HOSPITALISATION == "1") + cases.DAYS_IN_HOSP_COVID_RELATED(ageFlag & DHBflag & cases.COVID_RELATED_HOSPITALISATION == "1") - 1, tExt);
            end
             epiDataPart{iArea} = table(t', repmat(areaNames(iArea), length(t), 1), nCasesByAge', nHospByAge_DOR', nHospByAge_DOA', nDiscByAge', 'VariableName', {'t', 'area', 'nCasesByAge', 'nHospByAge_DOR', 'nHospByAge_DOA', 'nDiscByAge'});
        end
        % Concatenate all areas into a single table
        epiData = vertcat(epiDataPart{:});
    
        % Caclulate national LOS distribution by age group    
        denom = zeros(1, nAges);
        for iAge = 1:nAges
            ageFlag = cases.Age >= ageBreaks_ext(iAge) & cases.Age < ageBreaks_ext(iAge+1);
            tFlag = cases.REPORT_DT >= readDate(iDt)-LOS_wStart & cases.REPORT_DT <= readDate(iDt)-LOS_wEnd;     % cases within window for analysing LOS
            % Note: -1 from all LOS calculations in the following because for someone admitted & discharged on same day DAYS_IN_HOSP_COVID_RELATED is recored as 1 
            % Tabulate LOS data by age group
            LOS = cases.DAYS_IN_HOSP_COVID_RELATED(ageFlag & tFlag & cases.COVID_RELATED_HOSPITALISATION == "1") - 1;
            LOS_freq(iAge, :) = histcounts(LOS, LOS_array_ext);
            nExcl_LOS(iAge) = sum(ageFlag & tFlag & cases.COVID_RELATED_HOSPITALISATION == "1")-sum(LOS_freq(iAge, :));
            nOver_LOS(iAge) = sum(LOS >= max(LOS_array_ext) );
            
            denom(iAge) = sum(ageFlag & tFlag & cases.COVID_RELATED_HOSPITALISATION == "1");
        end
        fprintf('LOS overall: excluded %i/%i (%.2f%%), of which %i/%i (%.2f%%) over maximum\n', sum(nExcl_LOS), sum(denom), 100*sum(nExcl_LOS)/sum(denom), sum(nOver_LOS), sum(denom), 100*sum(nOver_LOS)/sum(denom))
        
    
    
        % Tabulate onset to report data
        flag = cases.REPORT_DT >= readDate(iDt)-OtoR_wStart & cases.REPORT_DT <= readDate(iDt)-OtoR_wEnd;
        OtoR = days(cases.REPORT_DT(flag)-cases.ONSET_DT_COALESCED(flag));
        OtoR_freq = histcounts(OtoR, OtoR_array_ext);
        nExcl_OtoR = sum(~isnan(OtoR))-sum(OtoR_freq);
        nUnder_OtoR = sum(OtoR < OtoRMin);
        nOver_OtoR = sum(OtoR > OtoRMax);
        fprintf('OtoR: excluded %i/%i (%.2f%%), of which %i/%i (%.2f%%) under minimum, and %i/%i (%.2f%%) over maximum\n', nExcl_OtoR, sum(~isnan(OtoR)), 100*nExcl_OtoR/sum(~isnan(OtoR)), nUnder_OtoR, sum(~isnan(OtoR)), 100*nUnder_OtoR/sum(~isnan(OtoR)), nOver_OtoR, sum(~isnan(OtoR)), 100*nOver_OtoR/sum(~isnan(OtoR)))
        
        
        % Tabulate report to admission data
        flag = cases.COVID_RELATED_HOSPITALISATION == "1" & cases.REPORT_DT >= readDate(iDt)-RtoA_wStart & cases.REPORT_DT <= readDate(iDt)-RtoA_wEnd;
        RtoA = days(cases.ADMISSION_DT(flag)-cases.REPORT_DT(flag));
        RtoA_freq = histcounts(RtoA, RtoA_array_ext);
        nExcl_RtoA = sum(~isnan(RtoA))-sum(RtoA_freq);
        nUnder_RtoA = sum(RtoA < RtoAMin);
        nOver_RtoA = sum(RtoA > RtoAMax);    
        fprintf('RtoA: excluded %i/%i (%.2f%%), of which %i/%i (%.2f%%) under minimum, and %i/%i (%.2f%%) over maximum\n', nExcl_RtoA, sum(flag), 100*nExcl_RtoA/sum(~isnan(RtoA)), nUnder_RtoA, sum(flag), 100*nUnder_RtoA/sum(~isnan(RtoA)), nOver_RtoA, sum(flag), 100*nOver_RtoA/sum(~isnan(RtoA)))
        
    
        % Save results as .csv 
        fOut = saveFolder + "/epiData_" + string(dateLbl);
        writetable(epiData, fOut + ".csv");
    
        OtoRData = table(OtoR_array', OtoR_freq', 'VariableNames', {'OtoR', 'freq'});
        fOut = saveFolder+"/OtoRData_"+string(dateLbl);
        writetable(OtoRData, fOut+".csv");
    
        RtoAData = table(RtoA_array', RtoA_freq', 'VariableNames', {'RtoA', 'freq'});
        fOut = saveFolder+"/RtoAData_"+string(dateLbl);
        writetable(RtoAData, fOut+".csv");
        
        LOSData = table(ageBreaks', LOS_freq, 'VariableNames', {'Age', 'LOS_freq'});
        fOut = saveFolder+"/LOSData_"+string(dateLbl);
        writetable(LOSData, fOut+".csv");
    
        % Save all relevant variables as .mat file
        fOut = saveFolder+"/allData_"+string(dateLbl);
        save(fOut, 'epiData', 'ageBreaks', 'LOS_array', 'LOS_freq', 'RtoA_array', 'RtoA_freq', 'OtoR_array', 'OtoR_freq');
    else
        fprintf('Cannot find file %s, skipping this date\n', fName)
    end
end
