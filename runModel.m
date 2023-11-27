function results = runModel(areaName, date0, readDate, par, plotFlag)

% Function to run the forecast model for a given read date
% 
% USAGE: results = runModel(date0, readDate, par, plotFlag)
%
% INPUTS: areaName - name (or array of names) of the area to forecats for (either "National" or the name of a Region or Health District)
%         date0 - starting date for model simulartions
%         readDate - datestamp on the epi data file to read in 
%         par - structure of model parameters as returned by getPar()
%         plotFlag - if 1 a set of diagnostic plots will be produced
%
% OUTPUTS: results - table with the following fields:
%            - forecastDate - equal to readDate-1 which is the most recent case data in the dataset
%            - area - name of the area to which the forecast applies
%            - t - date to which forecasting outputs in that row of the table apply
%            - Iq - quantiles of the particle filter output for daily infections
%            - Cq - quantiles of the particle filter output for daily cases
%            - Cq_smoothed - quantiles of the particle filter output for 7-day rolling average of daily cases
%            - Aq - quantiles of the particle filter output for daily admissions
%            - Dq - quantiles of the particle filter output for daily discharges
%            - Hq - quantiles of the particle filter output for hospital occupancy

meta = getMetaData();       % Get meta data on Health Districts and Regions

fprintf('Running model on data from %s', readDate);


% Check necessary data file exists - if not use subsequent week's data file if available
fileDate = readDate;
fName = sprintf('data/allData_%s.mat', datetime(readDate, 'Format', "yyyy-MM-dd"));
fNameBackup = sprintf('data/allData_%s.mat', datetime(readDate+7, 'Format', "yyyy-MM-dd"));
if exist(fName, 'file')
    fExist = 1;
    fprintf('\n')
elseif exist(fNameBackup, 'file')
    fExist = 1;
    fileDate = readDate+7;
    fName = fNameBackup;
    fprintf(' - no data found using trunatced data from %s\n', datetime(fileDate, 'Format', "yyyy-MM-dd"))
else
    fExist = 0;
    results = [];
    fprintf(' - no data found - skipping\n')
end



if fExist == 1
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Data importing & processing
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Read in epi data
    [epiData, ageBreaks, LOS_array, LOS_freq, RtoA_array, RtoA_freq, OtoR_array, OtoR_freq] = getEpiData(fileDate);
    
    % Read in hopsital occupancy data (MOH Github)
    hospData = getHospData(meta);
    
    % Process data and merge tables
    epiDataAll = processData(epiData, hospData, date0);
    
    % Remove any data on or after readDate (this should only have an effect when a data file is missing and the subsequent week's data file is being used instead) 
    epiDataAll(epiDataAll.t >= readDate, :) = [];
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Construct infection to report distribution from assumed incubation period
    % distribution and empirical onset to report data
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    OtoR_relFreq = OtoR_freq/sum(OtoR_freq);        % calculate relative frequencies
    
    ItoR_array = 1+OtoR_array(1):length(par.incub)+OtoR_array(end);
    ItoR_relFreq = conv(par.incub, OtoR_relFreq);       % convolution of incubation period and onset to report distributions
    ItoR_relFreq = ItoR_relFreq(ItoR_array >= 1 & ItoR_array <= par.tBurnIn);       % truncate to ignore infection to report times that are non-positive or greater than burn-in time
    ItoR_array = ItoR_array(ItoR_array >= 1 & ItoR_array <= par.tBurnIn);       
    ItoR_relFreq = ItoR_relFreq/sum(ItoR_relFreq);                      % renormalise
    
 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Fit model for CHR nationally if working in national mode
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if par.hospModelMode == "national"
        % Extract table of national epi data:
        epiDataNatl = filterAndSmooth(epiDataAll, "National");        
        % Fit CHR model
        [mdlHospNational, fittedFlagNational] = fitPHospModel(epiDataNatl, ageBreaks, par);           
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Loop through all areas specified in areaName
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    nAreas = length(areaName);
    parfor iArea = 1:nAreas
        fprintf('  area %s: fitting GPR models... ', areaName(iArea))
        
        % Extract table of epi data for current forecast area:
        epiDataArea = filterAndSmooth(epiDataAll, areaName(iArea));
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Fit models for CHR and age distirbution of cases 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        if par.hospModelMode == "national"
            mdlHosp = mdlHospNational;
            fittedFlag = fittedFlagNational;
        elseif par.hospModelMode == "local"
            [mdlHosp, fittedFlag] = fitPHospModel(epiDataArea, ageBreaks, par);           % use local area data for CHR model 
        else
            error('Expected par.hospModelMode to be either "national" or "local"');
        end        
    
        mdlCase = fitCaseDistModel(epiDataArea, ageBreaks, par);        % use area data for case age distriburtion model

        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Run renewal equation particle filer model
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        fprintf('running particle filter... ');
        
        % Set up array of times including forecast period
        t = [epiDataArea.t; (epiDataArea.t(end)+1:readDate-1+par.forecastPeriod)'];
        
        [Rt, It, Zt, Ct, LL, ESS] = runPF(t, epiDataArea, ItoR_array, ItoR_relFreq, par);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Apply hospitalisation model to output from particle filter
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        fprintf('applying hosp model...')
        
        [At, Dt, Ht, pCasesSamp, pHospSamp, CHR] = applyHospModel(t, It, mdlCase, mdlHosp, fittedFlag, epiDataArea, ageBreaks, LOS_array, LOS_freq, RtoA_array, RtoA_freq, ItoR_array, ItoR_relFreq, par);
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Calculate quantiles of key outputs and store in table
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        Rq = quantile(Rt, par.qt)';
        Iq = quantile(It, par.qt)';
        Cq = quantile(Ct, par.qt)';
        Cq_smoothed = quantile(smoothdata(Ct, 2, 'movmean', 7), par.qt)';
        Aq = quantile(At, par.qt)';
        Dq = quantile(Dt, par.qt)';
        Hq = quantile(Ht, par.qt)';
    
        forecastDate = repmat(readDate-1, length(t), 1);
        area = repmat(areaName(iArea), length(t), 1);
        results{iArea} = table(forecastDate, area, t, Rq, Iq, Cq, Cq_smoothed, Aq, Dq, Hq, ESS);
        fprintf('done\n');
        
        if plotFlag == 1 && iArea == 1
            % Diagnostic plots
            extraPlots(readDate, epiDataArea, mdlCase, mdlHosp, fittedFlag, pCasesSamp, pHospSamp, t, Rt, It, Ct, At, Dt, Ht, CHR, ageBreaks, par, date0);
        end
    
    end
    
    % Concatenate results for all areas into a single table:
    results = vertcat(results{:});
end

