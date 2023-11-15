% Top level script to run a single forecast based on data available at specified date (and optionally compare with data form a subsequent date)

clear 
close all

rng(56345);     % for reproducibility


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Basic parameters 

% Set areaName to "National", "Northern_region", "Midland_region", "Central_region", "Southern_region", or one of the following Health Districts: "Northland", "Waitemata", "Auckland", "Counties Manukau", "Waikato", "Bay of Plenty", "Lakes", "Tairawhiti", "Taranaki", "Whanganui", "Hawke's Bay", "Wairarapa", "Capital & Coast/Hutt", "MidCentral", "Nelson Marlborough", "Canterbury/West Coast", "South Canterbury", "Southern"
areaName = categorical("National");

date0 = datetime(2022, 8, 1);           % start date for model simulation
readDate = datetime(2023, 4, 17);        % forecasting date to run = datestamp on episurv data to use (Mondays), includes cases up to 1 day previous
testDate = datetime(2023, 5, 22);        % date for testing data (can be the same as readDate, or later if you want to compare to subsequent data)

% Label for output filenames
savLbl = sprintf("_data%s", datetime(readDate, 'format', 'yyyy-MM-dd'));

% Get model parameters
par = getPar();

% Run model
results = runModel(areaName, date0, readDate, par, 0);  
plotOneForecast(areaName, date0, testDate, results, savLbl); 

% Save results
fSav = "results/forecast" + savLbl;
save(fSav);
fSav = "results/forecast" + savLbl + ".csv";
writetable(results, fSav);









