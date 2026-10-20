% legend_setting.m
% 设置图例样式
% 调用方式：先 legend('曲线1','曲线2',...)，再 legend_setting;

hLegend = findobj(gcf, 'Type', 'Legend');
if ~isempty(hLegend)
    set(hLegend, 'FontName',  '宋体');
    set(hLegend, 'FontSize',   10);
    % 注意：MATLAB 的 'Box','off' 会同时去掉边框与背景填充，图例变成透明，
    % 数据曲线会直接压在图例文字上（密集时序图尤其严重，文字不可读）。
    % 这里用 'Box','on' 保留不透明白底，再把 EdgeColor 设为 none 去掉边框，
    % 即“无边框 + 不透明背景”。
    set(hLegend, 'Box',        'on');
    set(hLegend, 'EdgeColor',  'none');
    set(hLegend, 'Color',      'w');
    % Location 由各实验脚本自行设置，此处不覆盖
end