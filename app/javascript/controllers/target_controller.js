import { Controller } from "@hotwired/stimulus"
import { colors } from "graphs/common"
import { disposeCharts, resizeCharts } from "utils"
import { tooltipConfig, baseChartConfig, CHART_COLORS, wrapText, getGaugeChartConfig, hexToRgba, BRAND_FONT } from "config/chartConfig"

export default class extends Controller {
    static targets = ["reportsGrowth", "probesOverTime", "successRateGauge", "detectorActivity"]

    async connect() {
        await import("/js/echarts.js")

        this.charts = {}

        this.resizeHandler = () => resizeCharts(this.charts);
        window.addEventListener('resize', this.resizeHandler);

        this.initCharts()
    }

    disconnect() {
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
            this.resizeHandler = null;
        }
        disposeCharts(this.charts);
    }

    initCharts() {
        this.initReportsGrowthChart()
        this.initProbesOverTimeChart()
        this.initSuccessRateGaugeChart()
        this.initDetectorActivityChart()
    }

    initReportsGrowthChart() {
        if (this.charts.reportsGrowth) {
            this.charts.reportsGrowth.dispose()
        }

        this.charts.reportsGrowth = echarts.init(this.reportsGrowthTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = baseChartConfig(colors)

        fetch('/dashboard_stats/reports_timeline_data?target_id=' + this.element.dataset.id)
          .then(response => response.json())
          .then(data => {
            this.charts.reportsGrowth.setOption({
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
            })
          })
          .catch(error => {
            this.charts.reportsGrowth.setOption({
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
            })
          })
    }

    initProbesOverTimeChart() {
        if (this.charts.probesOverTime) {
            this.charts.probesOverTime.dispose()
        }

        this.charts.probesOverTime = echarts.init(this.probesOverTimeTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = baseChartConfig(colors)

        fetch('/dashboard_stats/probes_passed_failed_timeline_data?target_id=' + this.element.dataset.id)
            .then(response => response.json())
            .then(data => {
            if (data.dates.length === 0 || data.asr_percentages.length === 0) {
                this.charts.probesOverTime.setOption({
                    ...chartConfig,
                    title: {
                        text: 'No probe data available',
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

            this.charts.probesOverTime.setOption({
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
                    },
                    formatter: function (params) {
                        // Format the date to YYYY-MM-DD
                        let dateStr = params[0].axisValue;
                        let formattedDate = dateStr;

                        // Try to parse and format the date
                        try {
                            const date = new Date(dateStr);
                            if (!isNaN(date.getTime())) {
                                const year = date.getFullYear();
                                const month = String(date.getMonth() + 1).padStart(2, '0');
                                const day = String(date.getDate()).padStart(2, '0');
                                formattedDate = `${year}-${month}-${day}`;
                            }
                        } catch (e) {
                            // If parsing fails, use the original string
                        }

                        let result = `<div style="color: #9CA3AF; font-weight: normal; margin-bottom: 5px;">${formattedDate}</div>`;
                        params.forEach(function(param) {
                            const unit = param.seriesName.includes('ASR') ? '%' : '';
                            result += `<div style="margin: 2px 0;">
                                <span style="display:inline-block;margin-right:5px;border-radius:50%;width:10px;height:10px;background-color:${param.color};"></span>
                                ${param.seriesName}: ${param.value}${unit}
                            </div>`;
                        });
                        return result;
                    }
                },
                legend: {
                    data: ['Attack Success Rate (ASR)', 'Successful Attacks'],
                    top: 'bottom',
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
                yAxis: [
                    {
                        type: 'value',
                        name: 'Success Rate (%)',
                        nameLocation: 'middle',
                        nameGap: 40,
                        nameTextStyle: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT,
                            fontSize: 12
                        },
                        min: 0,
                        max: 100,
                        axisLine: {
                            show: true,
                            lineStyle: { color: colors.gridLineColor }
                        },
                        axisLabel: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT,
                            formatter: '{value}%'
                        },
                        splitLine: {
                            lineStyle: {
                                color: colors.gridLineColor,
                                type: 'dashed'
                            }
                        }
                    },
                    {
                        type: 'value',
                        name: 'Successful Attacks',
                        nameLocation: 'middle',
                        nameGap: 40,
                        nameTextStyle: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT,
                            fontSize: 12
                        },
                        position: 'right',
                        axisLine: {
                            show: true,
                            lineStyle: { color: colors.gridLineColor }
                        },
                        axisLabel: {
                            color: colors.subTextColor,
                            fontFamily: BRAND_FONT,
                            formatter: '{value}'
                        },
                        splitLine: {
                            show: false
                        }
                    }
                ],
                series: [
                    {
                        name: 'Attack Success Rate (ASR)',
                        type: 'line',
                        yAxisIndex: 0,
                        smooth: false,
                        symbol: 'none',
                        symbolSize: 0,
                        showSymbol: false,
                        data: data.asr_percentages,
                        connectNulls: true,
                        lineStyle: { width: 2, color: CHART_COLORS.RED },
                        itemStyle: {
                            color: CHART_COLORS.RED
                        }
                    },
                    {
                        name: 'Successful Attacks',
                        type: 'line',
                        yAxisIndex: 1,
                        smooth: false,
                        symbol: 'none',
                        symbolSize: 0,
                        showSymbol: false,
                        data: data.passed_counts,
                        connectNulls: true,
                        lineStyle: { width: 2, color: CHART_COLORS.ORANGE },
                        itemStyle: {
                            color: CHART_COLORS.ORANGE
                        }
                    }
                ]
            });
            })
            .catch(error => {
            this.charts.probesOverTime.setOption({
                ...chartConfig,
                title: {
                    text: 'Error loading ASR data',
                    left: 'center',
                    top: 'center',
                    textStyle: {
                        color: colors.textColor,
                        fontSize: 16
                    }
                }
            })
        })
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

        fetch('/dashboard_stats/probe_success_rate_data?target_id=' + this.element.dataset.id)
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

    initDetectorActivityChart() {
        if (!this.hasDetectorActivityTarget) return

        if (this.charts.detectorActivity) {
            this.charts.detectorActivity.dispose()
        }

        this.charts.detectorActivity = echarts.init(this.detectorActivityTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = baseChartConfig(colors)

        fetch('/dashboard_stats/detector_activity_data?target_id=' + this.element.dataset.id)
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
                        radius: '60%',
                        center: ['50%', '50%'],
                        indicator: indicators,
                        shape: 'circle',
                        nameGap: 35,
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
                                return wrapText(value, 15);
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
                                            { offset: 0, color: hexToRgba(CHART_COLORS.ORANGE, 0.6) },
                                            { offset: 1, color: hexToRgba(CHART_COLORS.ORANGE, 0.2) }
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
                                            { offset: 0, color: hexToRgba(CHART_COLORS.RED, 0.6) },
                                            { offset: 1, color: hexToRgba(CHART_COLORS.RED, 0.2) }
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
