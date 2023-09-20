% Top level script to run forecasts based on data available at one of a sequence of different (weekly) dates and compare each forecast with out of sample data over varying time horizons

clear 
close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Basic parameters 

% Set areaName to "National", "Northern_region", "Midland_region", "Central_region", "Southern_region", or one of the following Health Districts: "Northland", "Waitemata", "Auckland", "Counties Manukau", "Waikato", "Bay of Plenty", "Lakes", "Tairawhiti", "Taranaki", "Whanganui", "Hawke's Bay", "Wairarapa", "Capital & Coast/Hutt", "MidCentral", "Nelson Marlborough", "Canterbury/West Coast", "South Canterbury", "Southern"
areaName = "National";             

date0 = datetime(2022, 8, 1);           % start date for model simulation
readDate = datetime(2022, 10, 3):7:datetime(2023, 7, 24);       % range of forecasting dates to run = datestamp on episurv data to use (Mondays)
testDate = datetime(2023, 8, 21);        % date for testing data (can be the same as last readDate, or later if you want to compare to subsequent data)


% Get model parameters
par = getPar();


% Loop through forecast dates
nDates = length(readDate);
parfor iDate = 1:nDates
    results{iDate} = runModel(areaName, date0, readDate(iDate), par, 0);  
end


savLbl = sprintf("_%s_data%s", strrep(strrep(areaName, "/", "_"), "&", "_"), datetime(readDate(end), 'format', 'yyyy-MM-dd'));


% Combine results from each forecast date into a
% single composite forecast table
forecastTable = vertcat(results{:});


% Plot graphs of latest model and comparing forecasts at different time points to out of sample data
[perf, combTable] = compareForecast(areaName, date0, testDate, forecastTable, savLbl, par);


%%
% Save results
fSav = "results/allForecasts" + savLbl;
save(fSav);

fSav = "results/performance" + savLbl + ".csv";
writetable(perf, fSav);











