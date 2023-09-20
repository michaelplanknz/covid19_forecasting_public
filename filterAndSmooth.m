function epiDataArea = filterAndSmooth(epiDataAll, areaName)

epiDataArea = epiDataAll(epiDataAll.area == areaName, :);

epiDataArea.nCasesSmoothed = smoothdata(epiDataArea.nCases, 1, 'movmean', 7);
epiDataArea.nCasesSmoothed(end-2:end) = nan;     % Remove last three points in the cases moving average because the day-of-the-week reporting pattern means these are systematically biased 
epiDataArea.nHospSmoothed_DOR = smoothdata(epiDataArea.nHosp_DOR, 1, 'movmean', 7);
epiDataArea.HospSmoothed = smoothdata(epiDataArea.Hosp, 'movmean', 7);
