function mdlCase = fitCaseDistModel(epiData, ageBreaks, par)

% Function to fit a GP regression model to the distribution of cases among age groups
%
% USAGE: mdlCase = fitCaseDistModel(epiData, ageBreaks, par)
%
% INPUTS: epiData - table of epi date
%         ageBreaks - vector of bin edges defining age groups
%         par - structure of model parameters as returned by getPar()
%
% OUTPUTS: mdlCase - fitted GP regression object

nAges = length(ageBreaks);
% Fitting time period:
tIndAge = epiData.t > epiData.t(end)-par.ageSplitModel_wStart & epiData.t <= epiData.t(end)-par.ageSplitModel_wEnd;
% Data for proportion of cases in each band:
pCases = smoothdata(epiData.nCasesByAge, 1, 'movmean', 7)./epiData.nCasesSmoothed;
% log tranformed ratio for fitting to:
logRatCases = log(pCases./pCases(:, par.refAge));

% Fit data in each group (except for reference age group)
for iAge = 1:nAges
    if iAge ~= par.refAge
       mdlCase{iAge} = fitrgp(datenum(epiData.t(tIndAge)), logRatCases(tIndAge, iAge), 'KernelFunction', par.hospModelKernelFn);
    end
end
