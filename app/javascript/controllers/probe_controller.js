import { Controller } from "@hotwired/stimulus"
import { colors } from "graphs/common"
import { disposeCharts, resizeCharts } from "utils"
import { tooltipConfig, baseChartConfig, CHART_COLORS, getGaugeChartConfig, BRAND_FONT } from "config/chartConfig"

export default class extends Controller {
    static targets = ["scoresOverTime", "successRateGauge"]

    async connect() {
        await import("/js/echarts.js")

        this.charts = {}
        this.initCharts()

        this.resizeHandler = () => resizeCharts(this.charts);
        window.addEventListener('resize', this.resizeHandler);
    }

    disconnect() {
        if (this.resizeHandler) {
            window.removeEventListener('resize', this.resizeHandler);
            this.resizeHandler = null;
        }
        disposeCharts(this.charts);
    }

    initCharts() {
        this.initScoresOverTimeChart()
        this.initSuccessRateGaugeChart()
    }

    initScoresOverTimeChart() {
        if (this.charts.scoresOverTime) {
            this.charts.scoresOverTime.dispose()
        }

        this.charts.scoresOverTime = echarts.init(this.scoresOverTimeTarget, null, {
            renderer: 'canvas'
        })

        const chartConfig = baseChartConfig(colors)

        fetch('/dashboard_stats/probe_results_timeline_data?probe_id=' + this.element.dataset.id)
            .then(response => response.json())
            .then(data => {
                const colorPalette = [
                    CHART_COLORS.GREEN,  // Succeeded
                    CHART_COLORS.RED,    // Failed
                    CHART_COLORS.ORANGE  // Total
                ];

                const series = [
                    {
                        name: 'Succeeded',
                        type: 'line',
                        smooth: false,
                        symbol: 'none',
                        symbolSize: 0,
                        showSymbol: false,
                        data: data.passed_counts,
                        connectNulls: true,
                        lineStyle: { width: 2, color: colorPalette[0] },
                        itemStyle: {
                            color: colorPalette[0]
                        }
                    },
                    {
                        name: 'Failed',
                        type: 'line',
                        smooth: false,
                        symbol: 'none',
                        symbolSize: 0,
                        showSymbol: false,
                        data: data.failed_counts,
                        connectNulls: true,
                        lineStyle: { width: 2, color: colorPalette[1] },
                        itemStyle: {
                            color: colorPalette[1]
                        }
                    },
                    {
                        name: 'Total',
                        type: 'line',
                        smooth: false,
                        symbol: 'none',
                        symbolSize: 0,
                        showSymbol: false,
                        data: data.total_counts,
                        connectNulls: true,
                        lineStyle: { width: 2, color: colorPalette[2] },
                        itemStyle: {
                            color: colorPalette[2]
                        }
                    }
                ];

                this.charts.scoresOverTime.setOption({
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
                        data: ['Succeeded', 'Failed', 'Total'],
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
                console.error('Error fetching probe results data:', error);
                this.charts.scoresOverTime.setOption({
                    ...chartConfig,
                    title: {
                        text: 'Error loading probe results data',
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

        fetch('/dashboard_stats/probe_success_rate_data?probe_id=' + this.element.dataset.id)
            .then(response => response.json())
            .then(data => {
                const gaugeConfig = getGaugeChartConfig(data.success_rate, chartConfig);
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
}
