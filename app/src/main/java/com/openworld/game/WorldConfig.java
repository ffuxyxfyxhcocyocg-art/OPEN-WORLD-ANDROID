package com.openworld.game;

import org.json.JSONObject;

public final class WorldConfig {
    public final int gridRadius;
    public final float blockSpacing;
    public final float roadWidth;
    public final float buildingBaseHeight;
    public final float buildingHeightStep;

    private WorldConfig(int radius, float spacing, float road, float base, float step) {
        gridRadius = radius;
        blockSpacing = spacing;
        roadWidth = road;
        buildingBaseHeight = base;
        buildingHeightStep = step;
    }

    public static WorldConfig defaults() {
        return new WorldConfig(5, 8.0f, 9.0f, 3.5f, 1.2f);
    }

    public static WorldConfig fromJson(JSONObject json) {
        WorldConfig d = defaults();
        int radius = Math.max(2, Math.min(8, json.optInt("grid_radius", d.gridRadius)));
        float spacing = clamp((float) json.optDouble("block_spacing", d.blockSpacing), 6f, 14f);
        float road = clamp((float) json.optDouble("road_width", d.roadWidth), 5f, spacing - 1f);
        float base = clamp((float) json.optDouble("building_base_height", d.buildingBaseHeight), 2f, 8f);
        float step = clamp((float) json.optDouble("building_height_step", d.buildingHeightStep), 0.3f, 3f);
        return new WorldConfig(radius, spacing, road, base, step);
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }
}
