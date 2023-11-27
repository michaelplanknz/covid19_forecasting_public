function [perf, combTable] = compareForecast(areaName, date0, testDate, forecastTable, savLbl, par)

% Function to compare forecasts with subsequent data, plot comparison graphs, calculate performance statistics and save results
%
% USAGE: perf = compareForecast(date0, readDate, forecastTable, savLbl)
% 
% INPUTS: date0 - starting date for model simulartions
%         testDate - date stamp on the testing data set which will be used to evaluate the forecast accuracy
%         forecastTable - table of forecast outputs, formed by concatenating the outputs from calls 'runModel' with different read dates
%         savLbl - string used to label output files with the (most recent) read date and the run time
%
% OUTPUTS: perf - table containing forecast performance statistics at each look ahead time in the input vector nStepAhead
%          combTable - table containing data joined with forecasts and calculated scores

nStepAhead = [0 7 14 21];   % Number of days ahead to compare forecast to data

 % Exclude most recent hospital admission data from calculations for this many days due to reporting lag
 % This can be set to zero if forecasts are being evaluated with data at least 2 weeks after the final forecast date
tHospLag = 0;                 

% Read in epi data
[epiData] = getEpiData(testDate);

% Read in hopsital occupancy data (MOH Github)
meta = getMetaData();
hospData = getHospData(meta);

% Process data and merge tables
epiDataAll = processData(epiData, hospData, date0);

epiDataArea = filterAndSmooth(epiDataAll, areaName);



% Join data table and forecast table
combTable = innerjoin(epiDataArea, forecastTable, 'Keys', 't');

% Create performance indicators for each forecast variable
iMid = (size(combTable.Cq, 2)+1)/2;
nRows = height(combTable);
combTable.casesOverFlag = nan(nRows, 1);
combTable.casesSmoothedOverFlag = nan(nRows, 1);
combTable.admOverFlag = nan(nRows, 1);
combTable.occOverFlag = nan(nRows, 1);
combTable.casesInFlag = nan(nRows, 1);
combTable.casesSmoothedInFlag = nan(nRows, 1);
combTable.admInFlag = nan(nRows, 1);
combTable.occInFlag = nan(nRows, 1);
% Indicators for whether data is over model median
combTable.casesOverFlag(combTable.nCases > combTable.Cq(:, iMid)) = 1;
combTable.casesOverFlag(combTable.nCases < combTable.Cq(:, iMid)) = 0;
combTable.casesSmoothedOverFlag(combTable.nCasesSmoothed > combTable.Cq_smoothed(:, iMid)) = 1;
combTable.casesSmoothedOverFlag(combTable.nCasesSmoothed < combTable.Cq_smoothed(:, iMid)) = 0;
combTable.admOverFlag(combTable.nHosp_DOA > combTable.Aq(:, iMid)) = 1;
combTable.admOverFlag(combTable.nHosp_DOA < combTable.Aq(:, iMid)) = 0;
combTable.occOverFlag(combTable.Hosp > combTable.Hq(:, iMid)) = 1;
combTable.occOverFlag(combTable.Hosp < combTable.Hq(:, iMid)) = 0;
% Indicators for whether data is within 90% model CI
combTable.casesInFlag(combTable.nCases >= combTable.Cq(:, 1) & combTable.nCases <= combTable.Cq(:, end) ) = 1;
combTable.casesInFlag(combTable.nCases < combTable.Cq(:, 1) | combTable.nCases > combTable.Cq(:, end) ) = 0;
combTable.casesSmoothedInFlag(combTable.nCasesSmoothed >= combTable.Cq_smoothed(:, 1) & combTable.nCasesSmoothed <= combTable.Cq_smoothed(:, end) ) = 1;
combTable.casesSmoothedInFlag(combTable.nCasesSmoothed < combTable.Cq_smoothed(:, 1) | combTable.nCasesSmoothed > combTable.Cq_smoothed(:, end) ) = 0;
combTable.admInFlag(combTable.nHosp_DOA >= combTable.Aq(:, 1) & combTable.nHosp_DOA <= combTable.Aq(:, end) ) = 1;
combTable.admInFlag(combTable.nHosp_DOA < combTable.Aq(:, 1) | combTable.nHosp_DOA > combTable.Aq(:, end) ) = 0;
combTable.occInFlag(combTable.Hosp >= combTable.Hq(:, 1) & combTable.Hosp <= combTable.Hq(:, end) ) = 1;
combTable.occInFlag(combTable.Hosp < combTable.Hq(:, 1) | combTable.Hosp > combTable.Hq(:, end) ) = 0;


% Calculate CRPS scores on log(1+x) transformed data for each row in table
combTable.score_Ct = calcCRPS_quantiles( log(1+combTable.Cq), par.qt, log(1+combTable.nCases));
combTable.score_Ct_smoothed = calcCRPS_quantiles( log(1+combTable.Cq_smoothed), par.qt, log(1+combTable.nCasesSmoothed));
combTable.score_At = calcCRPS_quantiles( log(1+combTable.Aq), par.qt, log(1+combTable.nHosp_DOA));
combTable.score_Ht = calcCRPS_quantiles( log(1+combTable.Hq), par.qt, log(1+combTable.Hosp));

% Calculate bias for each row in table 
combTable.bias_Ct = calcBias(combTable.Cq, par.qt, combTable.nCases);
combTable.bias_Ct_smoothed = calcBias( combTable.Cq_smoothed, par.qt, combTable.nCasesSmoothed);
combTable.bias_At = calcBias(combTable.Aq, par.qt, combTable.nHosp_DOA);
combTable.bias_Ht = calcBias(combTable.Hq, par.qt, combTable.Hosp);


% Store summary statistics and scores in a performance table
nComps = length(nStepAhead);
perf.tAhead = zeros(nComps, 1);
perf.pCasesOver = zeros(nComps, 1);
perf.pCasesSmoothedOver = zeros(nComps, 1);
perf.pAdmOver = zeros(nComps, 1);
perf.pOccOver = zeros(nComps, 1);
perf.pCasesIn = zeros(nComps, 1);
perf.pCasesSmoothedIn = zeros(nComps, 1);
perf.pAdmIn = zeros(nComps, 1);
perf.pOccIn = zeros(nComps, 1);
perf.casesScore = zeros(nComps, 1);
perf.casesSmoothedScore = zeros(nComps, 1);
perf.admScore = zeros(nComps, 1);
perf.occScore = zeros(nComps, 1);
perf.casesBias = zeros(nComps, 1);
perf.casesSmoothedBias = zeros(nComps, 1);
perf.admBias = zeros(nComps, 1);
perf.occBias = zeros(nComps, 1);
perf = struct2table(perf);

% Plot graphs comparing n-step ahead forecasts with subsequent data
for iComp = 1:nComps
    % Subtable that only includes forecasts made in the relevant n-step
    % ahead period
    ind = combTable.t >= combTable.forecastDate+nStepAhead(iComp)-6 & combTable.t <= combTable.forecastDate+nStepAhead(iComp);
    forecastPart = combTable(ind, :);
    nRows = sum(ind);
    
    % Calculate performance metrics for this n-step ahead instance
    perf.tAhead(iComp) = nStepAhead(iComp);
    perf.pCasesOver(iComp) = nanmean(forecastPart.casesOverFlag);
    perf.pCasesSmoothedOver(iComp) = nanmean(forecastPart.casesSmoothedOverFlag );        
    perf.pAdmOver(iComp) = nanmean(forecastPart.admOverFlag(forecastPart.t <= max(combTable.t)-tHospLag) );                     % exclude last tHospLag days form calculation due to incomplete data
    perf.pOccOver(iComp) = nanmean(forecastPart.occOverFlag);
    perf.pCasesIn(iComp) = nanmean(forecastPart.casesInFlag);
    perf.pCasesSmoothedIn(iComp) = nanmean(forecastPart.casesSmoothedInFlag);
    perf.pAdmIn(iComp) = nanmean(forecastPart.admInFlag(forecastPart.t <= max(combTable.t)-tHospLag) );
    perf.pOccIn(iComp) = nanmean(forecastPart.occInFlag);    
    perf.casesScore(iComp) = nanmean(forecastPart.score_Ct);
    perf.casesSmoothedScore(iComp) = nanmean(forecastPart.score_Ct_smoothed );    
    perf.admScore(iComp) = nanmean(forecastPart.score_At(forecastPart.t <= max(combTable.t)-tHospLag) );
    perf.occScore(iComp) = nanmean(forecastPart.score_Ht);
    perf.casesBias(iComp) = nanmean(forecastPart.bias_Ct);
    perf.casesSmoothedBias(iComp) = nanmean(forecastPart.bias_Ct_smoothed );
    perf.admBias(iComp) = nanmean(forecastPart.bias_At(forecastPart.t <= max(combTable.t)-tHospLag) );
    perf.occBias(iComp) = nanmean(forecastPart.bias_Ht);
    
    % Make n-step ahead plots
    h = makePlots(forecastPart, min(forecastPart.t), max(forecastPart.t), 1, sprintf('%i day ahead forecast ', nStepAhead(iComp)) );
    if savLbl ~= ""
        fSav = sprintf("figures/n%idayAhead", nStepAhead(iComp)) + savLbl + ".png";
        saveas(h, fSav);
    end
end

% Plot score and bias
h = figure;
h.Position = [ 738   578   828   344];
subplot(1, 2, 1)
plot(perf.tAhead(2:end)/7, perf.casesScore(2:end), 'o-', perf.tAhead/7, perf.admScore, 'o-', perf.tAhead(2:end)/7, perf.occScore(2:end), 'o-' )
ylim([0 0.3])
xlabel('time horizon (weeks)')
ylabel('forecast score')
legend(["cases", "admissions", "occupancy"], 'Location', 'NorthWest')
title('(a)')
subplot(1, 2, 2)
plot(perf.tAhead(2:end)/7, perf.casesBias(2:end), 'o-', perf.tAhead/7, perf.admBias, 'o-', perf.tAhead(2:end)/7, perf.occBias(2:end), 'o-' )
yline(0, 'k:');
xlabel('time horizon (weeks)')
ylabel('forecast bias')
title('(b)')
if savLbl ~= ""
    fSav = "figures/scores" + savLbl + ".png";
    saveas(h, fSav);
end
