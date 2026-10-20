% line_setting.m
% 设置当前线条对象（hLine）的样式
% 调用方式：
%   hLine = plot(x, y);
%   line_setting;          % 对 hLine 设置默认样式
%   line_setting(hLine);   % 显式传入句柄

% 若未传入句柄，默认使用最后一次绘制的线条
if ~exist('hLine', 'var') || isempty(hLine)
    hLine = findobj(gca, 'Type', 'Line');
    if ~isempty(hLine)
        hLine = hLine(1);   % 取第一条线
    end
end

set(hLine, 'LineStyle', '-');
set(hLine, 'LineWidth', 1.5);
% set(hLine, 'Color', '#D9541A');   % 橙色示例，可按需修改
% set(hLine, 'Marker', 'none');