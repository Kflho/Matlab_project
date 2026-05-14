function Add_Threshold(threshold_value, threshold_label)
    % 功能：在当前活跃窗口的所有子图中添加红色阈值虚线，并精准更新 LaTeX 图例名
    % 参数：
    %   threshold_value: 阈值的数值
    %   threshold_label: 阈值的标签（建议使用 LaTeX 格式，如 '$\tau_{th}$'）

    if nargin < 2 || isempty(threshold_label)
        threshold_label = 'Threshold';
    end

    % 获取当前窗口的所有坐标轴
    all_axes = findobj(gcf, 'type', 'axes');

    for i = 1:length(all_axes)
        ax = all_axes(i);
        % 排除图例 (Legend) 和 颜色条 (Colorbar)
        if ~isempty(ax.Tag) && (contains(ax.Tag, 'Legend') || contains(ax.Tag, 'Colorbar'))
            continue; 
        end
        
        hold(ax, 'on');
        
        % --- 防止重复添加 ---
        existing_th = findobj(ax, 'Tag', 'ThresholdLine');
        if ~isempty(existing_th), delete(existing_th); end
        
        % 1. 画水平红虚线
        h_th = yline(ax, threshold_value, '--r', 'LineWidth', 2, 'Tag', 'ThresholdLine');
        h_th.DisplayName = threshold_label;
        
        % 2. 获取并更新图例
        lgd = shadowstate_get_legend(ax);
        
        if ~isempty(lgd)
            try
                % 获取配置
                old_loc = lgd.Location;
                old_font = lgd.FontSize;
                
                % 扫描坐标轴内所有需要显示的句柄
                all_plots = flipud(findobj(ax, 'Type', 'line', '-or', 'Type', 'constantline'));
                
                h_to_show = [];
                labels_to_show = {};
                
                for j = 1:length(all_plots)
                    obj = all_plots(j);
                    if strcmpi(get(obj, 'Annotation').LegendInformation.IconDisplayStyle, 'on') && ~isempty(obj.DisplayName)
                        h_to_show = [h_to_show; obj]; %#ok<AGROW>
                        
                        % --- 核心修复：自动处理 LaTeX 语法 ---
                        raw_label = obj.DisplayName;
                        % 如果包含下划线且没有被 $ 包裹，则自动包裹以符合 LaTeX 语法
                        if contains(raw_label, '_') && ~contains(raw_label, '$')
                            fixed_label = ['$', raw_label, '$'];
                        else
                            fixed_label = raw_label;
                        end
                        labels_to_show = [labels_to_show; {fixed_label}]; %#ok<AGROW>
                    end
                end
                
                % 排序：信号在前，阈值在后
                is_th = strcmp(get(h_to_show, 'Tag'), 'ThresholdLine');
                h_final = [h_to_show(~is_th); h_to_show(is_th)];
                labels_final = [labels_to_show(~is_th); labels_to_show(is_th)];

                % 销毁并重建
                delete(lgd); 
                new_lgd = legend(ax, h_final, labels_final, 'Location', old_loc, ...
                    'Interpreter', 'latex', 'FontSize', old_font);
                
                % 刷新布局
                set(new_lgd, 'Units', 'normalized'); 
                drawnow; 
                
            catch ME
                fprintf('Warning: Legend update failed. Error: %s\n', ME.message);
                % 容错处理：若 LaTeX 渲染失败，强制使用 none 解释器重新尝试一次
                legend(ax, h_final, labels_final, 'Location', old_loc, 'Interpreter', 'none');
            end
        else
            % 若无图例，则在红线上方标注
            final_label = threshold_label;
            if contains(final_label, '_') && ~contains(final_label, '$')
                final_label = ['$', final_label, '$'];
            end
            h_th.Label = final_label;
            h_th.Interpreter = 'latex';
            h_th.LabelVerticalAlignment = 'bottom';
            h_th.LabelHorizontalAlignment = 'right';
        end
    end
end

function lgd = shadowstate_get_legend(ax)
    lgd = [];
    fig = ancestor(ax, 'figure');
    if isempty(fig), return; end
    all_lgds = findobj(fig, 'Type', 'Legend');
    for k = 1:length(all_lgds)
        if isequal(all_lgds(k).Axes, ax)
            lgd = all_lgds(k);
            break;
        end
    end
end