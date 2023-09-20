function errorShade(x, y, clr)

x = reshape(x, 1, length(x));

[n, m] = size(y);
if n == length(x) & m ~= length(x)
    y = y.';
end
[n, m] = size(y);
nBands = (n-1)/2;
if nBands > 7
    fprintf(    'WARNING: errorShade cannot plot >7 bands\n\n')
end

clrCoeff = 0.75 - 0.2*(nBands/7)*linspace(-1, 1, nBands);

for iBand = 1:nBands
    ind1 = iBand;
    ind2 = 2*nBands+2-iBand;
    inLowerFlag = ~isnan(y(ind1, :));
    inUpperFlag = ~isnan(y(ind2, :));

    xShade = [x(inLowerFlag), fliplr(x(inUpperFlag))];
    yShade = [y(ind1, inLowerFlag), fliplr(y(ind2, inUpperFlag))];
    fill(xShade, yShade, clrCoeff(iBand) + (1-clrCoeff(iBand))*clr, 'LineStyle', 'none', 'HandleVisibility', 'off', 'FaceAlpha', 0.5)
    hold on
end
plot(x, y(nBands+1, :), 'Color', clr)
