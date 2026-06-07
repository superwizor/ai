// src/lib/charts/theme.ts
export const chartTheme = {
  ember:       '#FCAE2F',  // accent, primary series
  aurora:      '#6759FF',  // secondary series
  mist:        '#B2CACC',  // tertiary, grid lines
  magma:       '#D84515',  // error/negative
  frost:       '#FAFAFA',  // labels
  surfaceTeal: '#1F353A',  // card background
  nocturne:    '#002E32',  // chart area background
  glassBorder: '#3A5055',  // card border
  series: ['#FCAE2F', '#6759FF', '#B2CACC', '#D84515', '#004D54'],
  heatmapScale: ['#002E32', '#004D54', '#1F353A', '#FCAE2F'],
} as const;
