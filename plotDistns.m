% Script to plot some of the empirical distributions used in the model

clear 
close all

readDate = datetime(2023, 7, 24);       % data download date to plot


% Read in epi data
[epiData, ageBreaks, LOS_array, LOS_freq, RtoA_array, RtoA_freq, OtoR_array, OtoR_freq] = getEpiData(readDate);

ages = 5:10:95;
nAges = length(ages);

myColors = colororder;
myColors = [myColors; 0 0 0; 1 0 0; 0 1 0; 0.3 0.3 0; 0.3 0 0.3; 0 0.3 0.3; 0.3 0 0; 0 0.3 0; 0 0 0.3];

figure(1);
set(gcf, 'DefaultAxesColorOrder', myColors);

subplot(2, 2, 1)
bar(OtoR_array, OtoR_freq)
xlim([-8 8])
xlabel('onset to report time (days)')
ylabel('frequency')
title('(a)')

subplot(2, 2, 2)
bar(RtoA_array, RtoA_freq)
xlim([-8 8])
xlabel('report to admission time (days)')
ylabel('frequency')
title('(b)')


subplot(2, 2, 3)
losData = [];
losGrp =- [];
for iAge = 1:nAges
    losData = [losData, repelem(LOS_array, LOS_freq(iAge, :))];
    losGrp = [losGrp, iAge*ones(1, sum(LOS_freq(iAge, :)))];
end
boxplot(losData, losGrp,  'labels', ["0-10", "10-20", "20-30", "30-40", "40-50", "50-60", "60-70", "70-80", "80-90", "90+"], 'symbol', '', 'BoxStyle', 'filled')
xlabel('age (years)')
ylabel('mean length of stay')
ylim([0 30])
title('(c)')


