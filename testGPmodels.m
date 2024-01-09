% Script to fit and visualise GP regression models on a specified dataset

clear 
close all

areaName = "National";

% Basic parameters 
date0 = datetime(2022, 8, 1);           % start date for model simulation
readDate = datetime(2023, 4, 17);        % forecasting date to run = datestamp on episurv data to use (Mondays), includes cases up to 1 day previous
testDate = datetime(2023, 5, 22);        % date for testing data (can be the same as readDate, or later if you want to compare to subsequent data

% Number of samples to plot
nSamples = 1000;
nToPlot = 10;

% Get model parameters
par = getPar();


% Read in epi data for fitting
[epiDataFit, ageBreaks] = getEpiData(readDate);

meta = getMetaData();       % Get meta data on Health Districts and Regions

% Read in hopsital occupancy data (MOH Github)
hospData = getHospData(meta);

% Process data and merge tables
epiDataFit = processData(epiDataFit, hospData, date0);

epiDataFit = filterAndSmooth(epiDataFit, areaName);

% Read in updated data for model comparison
[epiDataTest, ~] = getEpiData(testDate);
epiDataTest = processData(epiDataTest, hospData, date0);    

epiDataTest = filterAndSmooth(epiDataTest, areaName);
epiDataTest = epiDataTest(epiDataTest.t <= readDate+21, :);   % only compare up to 3 weeks ahead of forecast date

% Fit models
mdlCase = fitCaseDistModel(epiDataFit, ageBreaks, par);
mdlHosp = fitPHospModel(epiDataFit, ageBreaks, par);

  

% Store model outputs (mean and CI)
t = epiDataTest.t;
nSteps = length(t);
nAges = length(ageBreaks);
pHospModelled = zeros(length(t), nAges);
pHospLow = zeros(length(t), nAges);
pHospHi = zeros(length(t), nAges);
for iAge = 1:nAges
    [yout, ~, yint] = predict(mdlHosp{iAge}, datenum(t));
    pHospModelled(:, iAge) = exp(yout)./(1+exp(yout));
    pHospLow(:, iAge) = exp(yint(:, 1))./(1+exp(yint(:, 1)));
    pHospHi(:, iAge) = exp(yint(:, 2))./(1+exp(yint(:, 2)));
end




% Generate model realisations
Alpha = 0.05;   % Note Alpha is the significance level for confidence intervals from the fitted GPRs but since the CI output is not used this the value of Alpha does not affect model outputs. 
mdlCaseSamp = zeros(nSamples, nSteps, nAges);
mdlHospSamp = zeros(nSamples, nSteps, nAges);
for iAge = 1:nAges
    if iAge ~= par.refAge
         [mdlCaseOut, covmat] = predictExactWithCov(mdlCase{iAge}.Impl, datenum(t), Alpha );              % mean and cov matrix output from GP regression. 
         T = cholcov(covmat);
         mdlCaseSamp(:, :, iAge) = mdlCaseOut' + randn(nSamples, nSteps)*T;   % Samples realisations from the fitted GPR as a multivariate normal with mean mdlCaseOut and covariance matrix covmat
    else
        mdlCaseSamp(:, :, iAge) = zeros(nSamples, nSteps);
    end
   [mdlHospOut, covmat] = predictExactWithCov(mdlHosp{iAge}.Impl, datenum(t), Alpha );      % mean and cov matrix output from GP regression. 
   T = cholcov(covmat);
   mdlHospSamp(:, :, iAge) = mdlHospOut' +  randn(nSamples, nSteps)*T;
end
pCasesSamp = exp(mdlCaseSamp)./sum(exp(mdlCaseSamp), 3);       % proportion of cases that are in each age group
pHospSamp = exp(mdlHospSamp)./(1+exp(mdlHospSamp));            % proportion of cases in each age group that are hopsitalised

% For the case age distribution model, the output of interest (pCases) is a function of all the outputs of all the age models (ratio of that age group to the baseline group)
% So to construct prediction intervals, need to sample from each model, compute pCases for the sample, and then take statistics:
pCasesModelled = squeeze(mean(pCasesSamp));
pCasesHi = pCasesModelled + 1.96*squeeze(std(pCasesSamp));
pCasesLow = pCasesModelled - 1.96*squeeze(std(pCasesSamp));



% Plotting
greyCol = [0.6 0.6 0.6];
greenCol = [0 0.6 0.2];
myColors = colororder;
myColors = [myColors; 0 0 0; 1 0 0; 0 1 0; 0.3 0.3 0; 0.3 0 0.3; 0 0.3 0.3; 0.3 0 0; 0 0.3 0; 0 0 0.3];

    

pCases = smoothdata(epiDataTest.nCasesByAge, 1, 'movmean', 7)./epiDataTest.nCasesSmoothed;
pHosp = smoothdata(epiDataTest.nHospByAge_DOR, 1, 'movmean', 7)./smoothdata(epiDataTest.nCasesByAge, 1, 'movmean', 7);


figure(1)
set(gcf, 'DefaultAxesColorOrder', myColors);
subplot(2, 2, 1)
plot(epiDataTest.t, pCases(:, 1:5), '.-')
hold on
set(gca, 'ColorOrderIndex', 1)
plot(t, pCasesModelled(:, 1:5))
set(gca, 'ColorOrderIndex', 1)
plot(t, pCasesLow(:, 1:5), '--')
set(gca, 'ColorOrderIndex', 1)
plot(t, pCasesHi(:, 1:5), '--')
ylabel('proportion of cases')
legend("0-10", "10-20", "20-30", "30-40", "40-50");
xline(epiDataFit.t(end)-par.ageSplitModel_wStart, 'k:', 'HandleVisibility', 'off');
xline(epiDataFit.t(end)-par.ageSplitModel_wEnd, 'k:', 'HandleVisibility', 'off');
xlim([epiDataFit.t(end)-par.ageSplitModel_wStart-7, epiDataTest.t(end)])
title('(a)')

subplot(2, 2, 2)
plot(epiDataTest.t, pCases(:, 6:end), '.-')
hold on
set(gca, 'ColorOrderIndex', 1)
plot(t, pCasesModelled(:, 6:end))
set(gca, 'ColorOrderIndex', 1)
plot(t, pCasesLow(:, 6:end), '--')
set(gca, 'ColorOrderIndex', 1)
plot(t, pCasesHi(:, 6:end), '--')
ylabel('proportion of cases')
legend("50-60", "60-70", "70-80", "80-90", "90+");
xline(epiDataFit.t(end)-par.ageSplitModel_wStart, 'k:', 'HandleVisibility', 'off');
xline(epiDataFit.t(end)-par.ageSplitModel_wEnd, 'k:', 'HandleVisibility', 'off');
xlim([epiDataFit.t(end)-par.ageSplitModel_wStart-7, epiDataTest.t(end)])
title('(b)')


subplot(2, 2, 3)
set(gcf, 'DefaultAxesColorOrder', myColors);
plot(epiDataTest.t, pHosp(:, 1:5), '.-')
hold on
set(gca, 'ColorOrderIndex', 1)
plot(t, pHospModelled(:, 1:5))
set(gca, 'ColorOrderIndex', 1)
plot(t, pHospLow(:, 1:5), '--')
set(gca, 'ColorOrderIndex', 1)
plot(t, pHospHi(:, 1:5), '--')
ylabel('CHR')
legend("0-10", "10-20", "20-30", "30-40", "40-50");
xline(epiDataFit.t(end)-par.hospModel_wStart, 'k:', 'HandleVisibility', 'off');
xline(epiDataFit.t(end)-par.hospModel_wEnd, 'k:', 'HandleVisibility', 'off');
xlim([epiDataFit.t(end)-par.hospModel_wStart-7, epiDataTest.t(end)])
title('(c)')

subplot(2, 2, 4)
set(gcf, 'DefaultAxesColorOrder', myColors);
plot(epiDataTest.t, pHosp(:, 6:end), '.-')
hold on
set(gca, 'ColorOrderIndex', 1)
plot(t, pHospModelled(:, 6:end))
set(gca, 'ColorOrderIndex', 1)
plot(t, pHospLow(:, 6:end), '--')
set(gca, 'ColorOrderIndex', 1)
plot(t, pHospHi(:, 6:end), '--')
ylabel('CHR')
legend("50-60", "60-70", "70-80", "80-90", "90+");
xline(epiDataFit.t(end)-par.hospModel_wStart, 'k:', 'HandleVisibility', 'off');
xline(epiDataFit.t(end)-par.hospModel_wEnd, 'k:', 'HandleVisibility', 'off');
xlim([epiDataFit.t(end)-par.hospModel_wStart-7, epiDataTest.t(end)])
title('(d)')






ageLbl = ["0-10", "10-20", "20-30", "30-40", "40-50", "50-60", "60-70", "70-80", "80-90", "90+"];

figure(2)
for iAge = 1:nAges
    subplot(3, 4, iAge)
    hold on
    plot(t, pCasesSamp(1:nToPlot, :, iAge), 'Color', greyCol)
    plot(t, pCasesModelled(:, iAge), 'b-')
    plot(t, pCasesLow(:, iAge), 'b--')
    plot(t, pCasesHi(:, iAge), 'b--')
    plot(epiDataTest.t, pCases(:, iAge), '.-', 'color', greenCol)
    if mod(iAge, 4) == 1
        ylabel('proportion of cases in age group')
    end
    if iAge <= 6
        h = gca;
        h.XTickLabel={};
    end
%    legend('data', 'fitted mean', 'fitted lower', 'fitted upper', 'samples');
    xline(epiDataFit.t(end)-par.ageSplitModel_wStart, 'k:', 'HandleVisibility', 'off');
    xline(epiDataFit.t(end)-par.ageSplitModel_wEnd, 'k:', 'HandleVisibility', 'off');
    xlim([epiDataFit.t(end)-par.ageSplitModel_wStart-7, epiDataTest.t(end)])
    title(ageLbl(iAge));
end
sgtitle('(a)')


figure(3)
for iAge = 1:nAges
    subplot(3, 4, iAge)
    hold on
    plot(t, pHospSamp(1:nToPlot, :, iAge), 'Color', greyCol)
    plot(t, pHospModelled(:, iAge), 'b-')
    plot(t, pHospLow(:, iAge), 'b--')
    plot(t, pHospHi(:, iAge), 'b--')
    plot(epiDataTest.t, pHosp(:, iAge), '.-', 'color', greenCol)
    if mod(iAge, 4) == 1
        ylabel('CHR');
    end
    if iAge <= 6
        h = gca;
        h.XTickLabel={};
    end
    %legend('data', 'fitted mean', 'fitted lower', 'fitted upper', 'samples');
    xline(epiDataFit.t(end)-par.hospModel_wStart, 'k:', 'HandleVisibility', 'off');
    xline(epiDataFit.t(end)-par.hospModel_wEnd, 'k:', 'HandleVisibility', 'off'); 
    xlim([epiDataFit.t(end)-par.hospModel_wStart-7, epiDataTest.t(end)])
    title(ageLbl(iAge));
end
sgtitle('(b)')

