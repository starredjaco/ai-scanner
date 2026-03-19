import { Controller } from "@hotwired/stimulus"
import { colors } from "graphs/common"
import { disposeCharts, resizeCharts } from "utils"
import { baseChartConfig, CHART_COLOR_PALETTE, getGaugeChartConfig, BRAND_FONT } from "config/chartConfig"

export default class extends Controller {
    static targets = ["successRateGauge", "reportsTimeline", "attackFails", "detectorActivity"]

    async connect() {
        await import("/js/echarts.js")

        this.charts = {}
        this.initCharts()

        // Store handler reference for cleanup in disconnect()
        this.resizeHandler = () => resizeCharts(this.charts);
        window.addEventListener('resize', this.resizeHandler);
    }

    disconnect() {
        // Remove event listener before disposing charts to prevent memory leak
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
            this.resizeHandler = null;
        }
        disposeCharts(this.charts);
    }

    initCharts() {
        this.initSuccessRateGaugeChart()
        this.initReportsTimelineChart()
        this.initAttackFailsChart()
        this.initDetectorActivityChart()
    }

    initSuccessRateGaugeChart() {
        if (!this.hasSuccessRateGaugeTarget) return

        if (this.charts.successRateGauge) {
            this.charts.successRateGauge.dispose()
        }

        this.charts.successRateGauge = echarts.init(this.successRateGaugeTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = baseChartConfig(colors)

        fetch('/dashboard_stats/probe_success_rate_data?scan_id=' + this.element.dataset.id)
            .then(response => response.json())
            .then(data => {
                const gaugeConfig = getGaugeChartConfig(data.success_rate, chartConfig, 'Attack Success Rate');
                this.charts.successRateGauge.setOption(gaugeConfig);
            })
            .catch(error => {
                console.error('Error fetching probe success rate data:', error);
                this.charts.successRateGauge.setOption({
                    ...chartConfig,
                    title: {
                        text: 'Error loading success rate data',
                        left: 'center',
                        top: 'center',
                        textStyle: {
                            color: colors.textColor,
                            fontSize: 16
                        }
                    }
                });
            });
    }

    initReportsTimelineChart() {
        if (!this.hasReportsTimelineTarget) return

        if (this.charts.reportsTimeline) {
            this.charts.reportsTimeline.dispose()
        }

        this.charts.reportsTimeline = echarts.init(this.reportsTimelineTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = {
            textStyle: {
                color: colors.textColor,
                fontFamily: BRAND_FONT
            },
            legend: {
                textStyle: {
                    color: colors.textColor,
                    fontFamily: BRAND_FONT
                },
                icon: 'roundRect',
                itemGap: 20
            },
            title: {
                textStyle: { color: colors.textColor }
            }
        }

        const tooltipConfig = {
            backgroundColor: 'rgba(39, 39, 42, 0.6)',
            borderWidth: 0,
            textStyle: {
                color: '#FFFFFF',
                fontFamily: BRAND_FONT,
                fontSize: 12
            },
            padding: [8, 12],
            borderRadius: 12,
            shadowBlur: 10,
            shadowColor: 'rgba(0, 0, 0, 0.3)',
            shadowOffsetY: 2,
            extraCssText: '-webkit-backdrop-filter: blur(6px); backdrop-filter: blur(6px);'
        }

        fetch('/dashboard_stats/reports_timeline_data?scan_id=' + this.element.dataset.id)
            .then(response => response.json())
            .then(data => {
                this.charts.reportsTimeline.setOption({
                    ...chartConfig,
                    backgroundColor: 'transparent',
                    tooltip: {
                        ...tooltipConfig,
                        trigger: 'axis',
                        axisPointer: {
                            type: 'line',
                            lineStyle: {
                                color: colors.primary,
                                opacity: 0.5
                            }
                        }
                    },
                    legend: {
                        data: ['Total Reports'],
                        bottom: 0,
                        icon: 'rect',
                        itemWidth: 15,
                        itemHeight: 2,
                        itemGap: 15,
                        textStyle: {
                            fontSize: 9,
                            color: 'rgba(255, 255, 255, 0.87)',
                            fontWeight: 300,
                            fontFamily: BRAND_FONT,
                            lineHeight: 11.855
                        },
                        orient: 'horizontal'
                    },
                    grid: {
                        left: '8%',
                        right: '8%',
                        bottom: '8%',
                        top: '3%',
                        containLabel: true
                    },
                    xAxis: {
                        type: 'category',
                        boundaryGap: false,
                        data: data.dates,
                        axisLine: { lineStyle: { color: colors.gridLineColor, width: 2 } },
                        axisLabel: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT,
                            rotate: 30,
                            fontSize: 11,
                            margin: 14
                        }
                    },
                    yAxis: {
                        type: 'value',
                        axisLine: {
                            show: true,
                            lineStyle: { color: colors.gridLineColor }
                        },
                        axisLabel: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT
                        },
                        splitLine: {
                            lineStyle: {
                                color: colors.gridLineColor,
                                type: 'dashed'
                            }
                        }
                    },
                    series: [
                        {
                            name: 'Total Reports',
                            type: 'line',
                            smooth: false,
                            symbol: 'none',
                            symbolSize: 0,
                            showSymbol: false,
                            data: data.counts,
                            connectNulls: true,
                            lineStyle: { width: 2, color: colors.primary },
                            itemStyle: {
                                color: colors.primary
                            }
                        }
                    ]
                });
            })
            .catch(error => {
                console.error('Error fetching reports timeline data:', error);
                this.charts.reportsTimeline.setOption({
                    ...chartConfig,
                    title: {
                        text: 'Error loading reports data',
                        left: 'center',
                        top: 'center',
                        textStyle: {
                            color: colors.textColor,
                            fontSize: 16
                        }
                    }
                });
            });
    }

    initAttackFailsChart() {
        if (!this.hasAttackFailsTarget) return

        if (this.charts.attackFails) {
            this.charts.attackFails.dispose()
        }

        this.charts.attackFails = echarts.init(this.attackFailsTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = {
            textStyle: {
                color: colors.textColor,
                fontFamily: BRAND_FONT
            },
            legend: {
                textStyle: {
                    color: colors.textColor,
                    fontFamily: BRAND_FONT
                },
                icon: 'roundRect',
                itemGap: 20
            },
            title: {
                textStyle: { color: colors.textColor }
            }
        }

        const tooltipConfig = {
            backgroundColor: 'rgba(39, 39, 42, 0.6)',
            borderWidth: 0,
            textStyle: {
                color: '#FFFFFF',
                fontFamily: BRAND_FONT,
                fontSize: 12
            },
            padding: [8, 12],
            borderRadius: 12,
            shadowBlur: 10,
            shadowColor: 'rgba(0, 0, 0, 0.3)',
            shadowOffsetY: 2,
            extraCssText: '-webkit-backdrop-filter: blur(6px); backdrop-filter: blur(6px);'
        }

        fetch('/dashboard_stats/attack_fails_by_target_data?scan_id=' + this.element.dataset.id)
            .then(response => response.json())
            .then(data => {
                const colorPalette = CHART_COLOR_PALETTE;

                let series;
                if (data.targets.length === 0) {
                    // Show 0 per day when no data is present
                    series = [{
                        name: 'No Data',
                        type: 'line',
                        smooth: false,
                        symbol: 'none',
                        symbolSize: 0,
                        showSymbol: false,
                        data: new Array(data.dates.length).fill(0),
                        connectNulls: true,
                        lineStyle: { width: 2, color: colors.subTextColor },
                        itemStyle: {
                            color: colors.subTextColor
                        }
                    }];
                } else {
                    series = data.targets.map((target, index) => {
                        const colorIndex = index % colorPalette.length;

                        return {
                            name: target.name,
                            type: 'line',
                            smooth: false,
                            symbol: 'none',
                            symbolSize: 0,
                            showSymbol: false,
                            data: target.failed_data,
                            connectNulls: true,
                            lineStyle: { width: 2, color: colorPalette[colorIndex] },
                            itemStyle: {
                                color: colorPalette[colorIndex]
                            }
                        };
                    });
                }

                this.charts.attackFails.setOption({
                    ...chartConfig,
                    backgroundColor: 'transparent',
                    tooltip: {
                        ...tooltipConfig,
                        trigger: 'axis',
                        axisPointer: {
                            type: 'line',
                            lineStyle: {
                                color: colors.primary,
                                opacity: 0.5
                            }
                        }
                    },
                    legend: {
                        data: data.targets.length === 0 ? ['No Data'] : data.targets.map(t => t.name),
                        bottom: 0,
                        icon: 'rect',
                        itemWidth: 15,
                        itemHeight: 2,
                        itemGap: 15,
                        textStyle: {
                            fontSize: 9,
                            color: 'rgba(255, 255, 255, 0.87)',
                            fontWeight: 300,
                            fontFamily: BRAND_FONT,
                            lineHeight: 11.855
                        },
                        orient: 'horizontal',
                        type: 'scroll',
                        pageButtonPosition: 'end'
                    },
                    grid: {
                        left: '8%',
                        right: '8%',
                        bottom: '12%',
                        top: '3%',
                        containLabel: true
                    },
                    xAxis: {
                        type: 'category',
                        boundaryGap: false,
                        data: data.dates,
                        axisLine: { lineStyle: { color: colors.gridLineColor, width: 2 } },
                        axisLabel: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT,
                            rotate: 30,
                            fontSize: 11,
                            margin: 14
                        }
                    },
                    yAxis: {
                        type: 'value',
                        axisLine: {
                            show: true,
                            lineStyle: { color: colors.gridLineColor }
                        },
                        axisLabel: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT
                        },
                        splitLine: {
                            lineStyle: {
                                color: colors.gridLineColor,
                                type: 'dashed'
                            }
                        }
                    },
                    series: series
                });
            })
            .catch(error => {
                console.error('Error fetching attack fails data:', error);
                this.charts.attackFails.setOption({
                    ...chartConfig,
                    title: {
                        text: 'Error loading attack fails data',
                        left: 'center',
                        top: 'center',
                        textStyle: {
                            color: colors.textColor,
                            fontSize: 16
                        }
                    }
                });
            });
    }

    initDetectorActivityChart() {
        if (!this.hasDetectorActivityTarget) return

        if (this.charts.detectorActivity) {
            this.charts.detectorActivity.dispose()
        }

        this.charts.detectorActivity = echarts.init(this.detectorActivityTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = {
            textStyle: {
                color: colors.textColor,
                fontFamily: BRAND_FONT
            },
            title: {
                textStyle: { color: colors.textColor }
            }
        }

        fetch('/dashboard_stats/detector_activity_data?scan_id=' + this.element.dataset.id)
            .then(response => response.json())
            .then(data => {
                if (!data.detector_names || data.detector_names.length === 0) {
                    this.charts.detectorActivity.setOption({
                        ...chartConfig,
                        title: {
                            text: 'No detector data available',
                            left: 'center',
                            top: 'center',
                            textStyle: {
                                color: colors.textColor,
                                fontSize: 16
                            }
                        }
                    })
                    return
                }

                const maxValue = Math.max(...data.test_counts) * 1.1 || 100;
                const indicators = data.detector_names.map((name) => ({
                    name: name,
                    max: maxValue
                }));

                this.charts.detectorActivity.setOption({
                    ...chartConfig,
                    backgroundColor: 'transparent',
                    tooltip: {
                        show: false
                    },
                    radar: {
                        radius: '55%',
                        center: ['50%', '50%'],
                        indicator: indicators,
                        shape: 'circle',
                        nameGap: 15,
                        splitArea: {
                            show: false
                        },
                        axisLine: {
                            lineStyle: { color: '#423412' }
                        },
                        splitLine: {
                            lineStyle: { color: '#423412' }
                        },
                        name: {
                            formatter: function(value) {
                                const maxCharsPerLine = 15;
                                if (value.length <= maxCharsPerLine) {
                                    return value;
                                }

                                const words = value.split(' ');
                                let lines = [];
                                let currentLine = '';

                                words.forEach(word => {
                                    if ((currentLine + ' ' + word).trim().length <= maxCharsPerLine) {
                                        currentLine = (currentLine + ' ' + word).trim();
                                    } else {
                                        if (currentLine) lines.push(currentLine);
                                        currentLine = word;
                                    }
                                });
                                if (currentLine) lines.push(currentLine);

                                return lines.join('\n');
                            },
                            textStyle: {
                                color: '#FFFFFF',
                                fontSize: 11,
                                fontWeight: 'normal',
                                fontFamily: BRAND_FONT,
                                backgroundColor: 'transparent',
                                borderRadius: 0
                            }
                        }
                    },
                    series: [
                        {
                            type: 'radar',
                            data: [
                                {
                                    value: data.test_counts,
                                    name: 'Total Tests',
                                    symbol: 'none',
                                    symbolSize: 0,
                                    lineStyle: {
                                        width: 2,
                                        color: '#423412'
                                    },
                                    areaStyle: {
                                        color: new echarts.graphic.LinearGradient(0, 0, 1, 1, [
                                            { offset: 0, color: 'rgba(249, 115, 22, 0.6)' },
                                            { offset: 1, color: 'rgba(249, 115, 22, 0.2)' }
                                        ])
                                    },
                                    emphasis: {
                                        lineStyle: { width: 2 }
                                    }
                                },
                                {
                                    value: data.passed_counts,
                                    name: 'Passed Tests',
                                    symbol: 'none',
                                    symbolSize: 0,
                                    lineStyle: {
                                        width: 2,
                                        color: '#DC2626'
                                    },
                                    areaStyle: {
                                        color: new echarts.graphic.LinearGradient(0, 0, 1, 1, [
                                            { offset: 0, color: 'rgba(220, 38, 38, 0.6)' },
                                            { offset: 1, color: 'rgba(220, 38, 38, 0.2)' }
                                        ])
                                    },
                                    emphasis: {
                                        lineStyle: { width: 2 }
                                    }
                                }
                            ]
                        }
                    ],
                    legend: {
                        show: false
                    }
                });
            })
            .catch(error => {
                console.error('Error fetching detector activity data:', error);
                this.charts.detectorActivity.setOption({
                    ...chartConfig,
                    title: {
                        text: 'Error loading detector activity data',
                        left: 'center',
                        top: 'center',
                        textStyle: {
                            color: colors.textColor,
                            fontSize: 16
                        }
                    }
                });
            });
    }
}
