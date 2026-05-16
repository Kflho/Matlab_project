function Run_visualization(figh)
% 应用论文统一图形格式。若未传入图窗句柄，默认对 gcf 操作。
    if nargin < 1 || isempty(figh)
        figh = gcf;
    end
    % 保护：无效句柄直接返回
    if ~ishandle(figh) || ~isvalid(figh)
        return;
    end
    figure(figh);   % 确保其为当前图窗

    % 检查坐标轴
    if isempty(get(figh, 'CurrentAxes'))
        return;
    end

    % 依次应用设置
    fig_setting;               % 白色背景（内部使用 gcf，因已 figure(figh) 故安全）
    axes_setting_2d;
    label_setting_2d;

    hLeg = findobj(figh, 'Type', 'Legend');
    if ~isempty(hLeg)
        legend_setting;
    end

    hTitle = get(figh, 'CurrentAxes');
    if ~isempty(hTitle) && ~isempty(get(hTitle, 'Title'))
        title_setting;
    end

    % 统一线条宽度
    hLines = findobj(figh, 'Type', 'Line', '-or', 'Type', 'ConstantLine');
    if ~isempty(hLines)
        set(hLines, 'LineWidth', 1.5);
    end
end