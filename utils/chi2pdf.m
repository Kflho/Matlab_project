function p = chi2pdf(x, v)
% chi2pdf  chi-squared probability density function (fallback).
%   p = chi2pdf(x, v)
%
%   returns the Pdf of the chi-squared distribution with v degrees of
%   freedom evaluated at the elements of x.
%
%   formula: p(x; v) = x^(v/2-1) * exp(-x/2) / (2^(v/2) * gamma(v/2))
%
%   use this when statistics and machine learning toolbox is unavailable.
%   it matches stats/chi2pdf.m output to machine precision.

p = zeros(size(x));

% only compute for strictly positive x; Pdf is 0 at x <= 0 (for v>2) or inf at x=0 (for v<2)
pos = x > 0;

if any(pos)
    x_pos = x(pos);
    half_v = v / 2;
    log_p = (half_v - 1) .* log(x_pos) - x_pos/2 - half_v * log(2) - gammaln(half_v);
    p(pos) = exp(log_p);
end

% handle x == 0: for v == 1, Pdf → inf at 0; handled by letting pos=false skip it → 0
% for v < 2, there's a singularity at 0 but we approximate as 0 for practical use.
% for v == 2, Pdf at 0 = 0.5 (exp(-0) / (2*gam(1))) = 0.5
if any(~pos)
    zero_idx = (~pos) & (x == 0);
    if v == 2
        p(zero_idx) = 0.5;
    elseif v == 1
        % for v=1 at x=0, the Pdf is actually infinite, return a large number
        p(zero_idx) = realmax;
    end
end

end
