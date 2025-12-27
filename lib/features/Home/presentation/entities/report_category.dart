enum ReportCategory {
  roadsInfrastructure('Roads & Infrastructure', true),
  waterSupply('Water Supply', true),
  garbageWaste('Garbage & Waste', true),
  drainageSewage('Drainage & Sewage', true),
  electricityStreetlights('Electricity & Streetlights', false),
  others('Others', false);

  final String displayName;
  final bool useAITitle;

  const ReportCategory(this.displayName, this.useAITitle);
}