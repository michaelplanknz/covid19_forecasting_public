% Script to visualise differences between datasets available at different dates

clear 
close all

% Set areaName to "National", "Northern_region", "Midland_region", "Central_region", "Southern_region", or one of the following Health Districts: "Northland", "Waitemata", "Auckland", "Counties Manukau", "Waikato", "Bay of Plenty", "Lakes", "Tairawhiti", "Taranaki", "Whanganui", "Hawke's Bay", "Wairarapa", "Capital & Coast/Hutt", "MidCentral", "Nelson Marlborough", "Canterbury/West Coast", "South Canterbury", "Southern"
areaName = "National";        

date0 = datetime(2022, 9, 1);                              % start date for plotting
%fdts = datetime(2022, 11, 28):28:datetime(2023, 4, 3);       % range of data download dates to plot
fdts = datetime(2023, 3, 27):28:datetime(2023, 7, 17);       % range of data download dates to plot
nDates = length(fdts);

meta = getMetaData();       % Get meta data on Health Districts and Regions

% Loop through forecast dates
for iDate = 1:nDates
% Read in epi data
    [tmp] = getEpiData(fdts(iDate));

    % Read in hopsital occupancy data (MOH Github)
    hospData = getHospData(meta);

    % Process data and merge tables
    epiData{iDate} = processData(tmp, hospData, date0);
end


figure(1);
subplot(1, 2, 1)
for iDate = 1:nDates
    inFlag = epiData{nDates+1-iDate}.area == areaName;
    plot(epiData{nDates+1-iDate}.t(inFlag), epiData{nDates+1-iDate}.nCases(inFlag))
    xline(fdts(nDates+1-iDate), 'k:', 'HandleVisibility', 'off');
    hold on
end
ylabel('daily cases')
title('(a)')


subplot(1, 2, 2)
for iDate = 1:nDates
    inFlag = epiData{nDates+1-iDate}.area == areaName;
    plot(epiData{nDates+1-iDate}.t(inFlag), epiData{nDates+1-iDate}.nHosp_DOA(inFlag))
    xline(fdts(nDates+1-iDate), 'k:', 'HandleVisibility', 'off');
    hold on
end
ylabel('new daily admissions')
legend(string(fliplr(fdts-1)))
title('(b)')

