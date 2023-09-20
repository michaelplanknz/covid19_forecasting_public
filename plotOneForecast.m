function plotOneForecast(areaName, date0, readDate, results, savLbl)


% Read in epi data
[epiData] = getEpiData(readDate);

% Read in hopsital occupancy data (MOH Github)
meta = getMetaData();
hospData = getHospData(meta);

% Process data and merge tables
epiDataAll = processData(epiData, hospData, date0);

% Only plot data up to end of forecast period
tMax = max(results.t);

for iArea = 1:length(areaName)
    epiDataArea = filterAndSmooth(epiDataAll, areaName(iArea));
    areaNameString = strrep(strrep(string(areaName(iArea)), '&', '_'), '/', '_');
    
    
    % Join data table and results table
    resultsJoined = outerjoin(epiDataArea, results(results.area == areaName(iArea), :), 'Keys', 't', 'MergeKeys', 1);
    
    % Plot graphs of model fitted to latest data and projected forwards in time
    h = makePlots(resultsJoined, readDate-70, tMax, 0, '');
    if savLbl ~= ""
        fSav = sprintf("figures/forecast_%s%s.png", areaNameString, savLbl);
        saveas(h, fSav);
    end
    
    
end
