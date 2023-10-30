function [mdlHosp, fittedFlag] = fitPHospModel(epiData, ageBreaks, par)

% Function to fit a GP regression model for the case-hospitalistion ratio in each age group
%
% USAGE: mdlHosp = fitPHospModel(epiData, ageBreaks, par)
%
% INPUTS: epiData - table of epi date
%         ageBreaks - vector of bin edges defining age groups
%         par - structure of model parameters as returned by getPar()
%
% OUTPUTS: mdlHosp - a structure of fitted GP regression objects, one for each each group
%          fittedFlag - a flag vector indicating whether a GP regression model has been fitted in each age group 
%                       in age groups where fittedFlag = 0, mdlHosp will instead contain two fields to enable calculation of a binomial CI:
%                            - nTrials - total number of cases in the fitting window in the age group
%                            - nSuccess - number of those cases that were admitted


nAges = length(ageBreaks);
% Fitting time period:
tIndHosp = epiData.t > epiData.t(end)-par.hospModel_wStart & epiData.t <= epiData.t(end)-par.hospModel_wEnd;
% Data for probability of hospitalistion in each age band (proportion of cases admitted in a 7-day moving window):
pHosp = smoothdata(epiData.nHospByAge_DOR, 1, 'movmean', 7)./smoothdata(epiData.nCasesByAge, 1, 'movmean', 7);
fittedFlag = min(pHosp(tIndHosp, :)) > 0;      % flag indicating whether all vlaues of pHosp are strictly positive in the relevant time window for each age band

if sum(fittedFlag) < nAges
    fprintf('Warning: unable to fit full CHR model in age groups [')
    fprintf('%i ', find(~fittedFlag))
    fprintf('] due to zeros in smoothed p(hosp) values\n')
end

% logit transform for fitting:
logOddsHosp = log(pHosp./(1-pHosp));

% Fit model in each age band
for iAge = 1:nAges
    if fittedFlag(iAge)
        mdlHosp{iAge} = fitrgp(datenum(epiData.t(tIndHosp)), logOddsHosp(tIndHosp, iAge), 'KernelFunction', par.caseModelKernelFn);
    else
        mdlHosp{iAge}.nTrials = sum(epiData.nCasesByAge(tIndHosp, iAge));
        mdlHosp{iAge}.nSuccess = sum(epiData.nHospByAge_DOR(tIndHosp, iAge));
    end
end

