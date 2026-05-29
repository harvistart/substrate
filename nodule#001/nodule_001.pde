/*
 * HARVIST CONSORTIUM
 * Nodule #001 — First Fruiting
 * Substrate: Processing 4.0+
 * This sketch is a living document. Treat it as a hypha, not a blueprint.
 */

// PARAMETERS
int canvasW = 800;
int canvasH = 1000;
int totalFrames = 120;
float rotSpeed = 0.0035;
int walkerCount = 2000;
int trailLength = 8;
float noiseScale = 0.007;
float baseSpeed = 1.6;
float hAttraction = 0.22;
float spawnRadius = 290;
float trailRetention = 22;
int backBlur = 16;
int midBlur = 5;
int glowBlur = 16;            // INCREASED: more diffuse halo
float glowAlpha = 0.85;       // INCREASED: much stronger glow composite
int glowNodeCount = 280;      // INCREASED: nearly doubled glow nodes
// OpenGL hard limit: 8 lights TOTAL
// We use: 1 ambient + 7 pointLight = 8 total
int maxLights = 7;
color bioViolet = #8b5cf6;

// GLOBAL STATE
Walker[] walkers;
int[] lightCarriers;
int[] glowNodes;
PGraphics pgBack;
PGraphics pgMid;
PGraphics pgFront;
PGraphics pgGlow;
float[] projX;
float[] projY;
float[] projZ;
int frameCounter = 0;
float globalTheta = 0;

// --- WALKER CLASS ---
class Walker {
  PVector pos;
  PVector[] trail;
  int tIndex;
  int layer;
  float speed;
  float life;
  float maxLife;
  boolean isCorrupted;
  boolean isLight;
  boolean isGlow;
  float pulsePhase;
  float baseAlpha;

  Walker() {
    respawn();
  }

  void respawn() {
    if (random(1) < 0.55) {
      pos = hSpawn();
    } else {
      float theta = random(TWO_PI);
      float phi = acos(random(-1, 1));
      float r = random(40, spawnRadius);
      pos = new PVector(
        r * sin(phi) * cos(theta),
        r * cos(phi),
        r * sin(phi) * sin(theta)
      );
    }

    trail = new PVector[trailLength];
    for (int i = 0; i < trailLength; i++) trail[i] = pos.copy();
    tIndex = 0;

    float d = pos.mag();
    if (d > 190) layer = 0;
    else if (d > 95) layer = 1;
    else layer = 2;

    speed = baseSpeed * random(0.6, 1.4);
    float h = hField(pos.x, pos.y, pos.z);
    maxLife = random(40, 90) + h * 120;
    life = maxLife;

    isCorrupted = random(1) > 0.88;
    isLight = false;
    isGlow = false;
    pulsePhase = random(TWO_PI);
    baseAlpha = random(35, 85);
  }

  void update(float t) {
    float n1 = noise(pos.x * noiseScale, pos.y * noiseScale, pos.z * noiseScale + t * 0.015);
    float n2 = noise(pos.x * noiseScale * 2 + 300, pos.y * noiseScale * 2 + 300, pos.z * noiseScale * 2 + t * 0.01) * 0.5;
    float n3 = noise(pos.x * noiseScale * 4 + 600, pos.y * noiseScale * 4 + 600, pos.z * noiseScale * 4 + t * 0.008) * 0.25;
    float angle = (n1 + n2 + n3) * TWO_PI * 3;

    PVector noiseDir = new PVector(cos(angle), sin(angle * 0.7), cos(angle * 1.3));
    noiseDir.normalize();

    float h = hField(pos.x, pos.y, pos.z);
    PVector hDir = hGradient(pos.x, pos.y, pos.z);

    PVector vel = PVector.lerp(noiseDir, hDir, h * hAttraction);
    vel.mult(speed * (1.0 - h * 0.35));

    pos.add(vel);

    if (pos.mag() > spawnRadius + 20) {
      PVector toCenter = PVector.sub(new PVector(0, 0, 0), pos);
      toCenter.normalize();
      pos.add(toCenter.mult(2.5));
    }

    if (isCorrupted && random(1) > 0.92) {
      pos.add(PVector.random3D().mult(random(8, 22)));
    }

    trail[tIndex] = pos.copy();
    tIndex = (tIndex + 1) % trailLength;

    life--;
    if (life <= 0) respawn();
  }
}

// --- H-FIELD FUNCTIONS ---
float hField(float x, float y, float z) {
  float leftP = exp(-pow(x + 55, 2) / 900.0) * exp(-pow(z, 2) / 700.0) * (0.4 + 0.6 * exp(-pow(y * 0.035, 2)));
  float rightP = exp(-pow(x - 55, 2) / 900.0) * exp(-pow(z, 2) / 700.0) * (0.4 + 0.6 * exp(-pow(y * 0.035, 2)));
  float cross = exp(-pow(y, 2) / 500.0) * exp(-pow(z, 2) / 700.0);
  if (abs(x) > 50) cross *= exp(-pow(abs(x) - 50, 2) / 400.0);
  return max(leftP, rightP, cross * 0.75);
}

PVector hGradient(float x, float y, float z) {
  float eps = 6.0;
  float dx = hField(x + eps, y, z) - hField(x - eps, y, z);
  float dy = hField(x, y + eps, z) - hField(x, y - eps, z);
  float dz = hField(x, y, z + eps) - hField(x, y, z - eps);
  PVector g = new PVector(dx, dy, dz);
  g.normalize();
  return g;
}

PVector hSpawn() {
  for (int attempt = 0; attempt < 50; attempt++) {
    float x = random(-90, 90);
    float y = random(-160, 160);
    float z = random(-60, 60);
    if (random(1) < hField(x, y, z)) {
      return new PVector(x, y, z);
    }
  }
  return new PVector(random(-60, 60), random(-100, 100), random(-40, 40));
}

// SETUP
void setup() {
  size(800, 1000, P3D);
  background(0);

  randomSeed(1337);
  noiseSeed(7331);

  pgBack = createGraphics(canvasW, canvasH, P2D);
  pgMid = createGraphics(canvasW, canvasH, P2D);
  pgFront = createGraphics(canvasW, canvasH, P3D);
  pgGlow = createGraphics(canvasW, canvasH, P2D);

  projX = new float[walkerCount];
  projY = new float[walkerCount];
  projZ = new float[walkerCount];

  walkers = new Walker[walkerCount];
  for (int i = 0; i < walkerCount; i++) {
    walkers[i] = new Walker();
  }

  // assign 7 mobile pointLight carriers
  lightCarriers = new int[maxLights];
  for (int lc = 0; lc < maxLights; lc++) {
    int bestIdx = -1;
    float bestH = -1;
    for (int attempt = 0; attempt < 100; attempt++) {
      int idx = int(random(walkerCount));
      float h = hField(walkers[idx].pos.x, walkers[idx].pos.y, walkers[idx].pos.z);
      if (h > bestH && !walkers[idx].isLight && !walkers[idx].isGlow) {
        bestH = h;
        bestIdx = idx;
      }
    }
    if (bestIdx >= 0) {
      walkers[bestIdx].isLight = true;
      lightCarriers[lc] = bestIdx;
    } else {
      lightCarriers[lc] = lc * 250;
      walkers[lightCarriers[lc]].isLight = true;
    }
  }

  // assign 280 glow nodes — MANY MORE for dense violet coverage
  glowNodes = new int[glowNodeCount];
  int assigned = 0;
  while (assigned < glowNodeCount) {
    int idx = int(random(walkerCount));
    if (walkers[idx].isLight || walkers[idx].isGlow) continue;
    float h = hField(walkers[idx].pos.x, walkers[idx].pos.y, walkers[idx].pos.z);
    // higher chance to become glow node, especially in H-field
    if (random(1) < 0.55 + h * 0.4) {
      walkers[idx].isGlow = true;
      glowNodes[assigned] = idx;
      assigned++;
    }
  }

  println("// substrate inoculated — " + walkerCount + " hyphae colonized");
  println("// " + maxLights + " mobile pointLights + 1 ambient = 8 total (OpenGL limit)");
  println("// " + glowNodeCount + " glow nodes — dense violet halo");
}

// RENDER
void draw() {
  if (frameCounter >= totalFrames) {
    println("// fruiting complete — " + totalFrames + " cycles archived");
    noLoop();
    return;
  }

  float t = frameCounter;
  globalTheta += rotSpeed;

  // temporal motion blur
  background(0, int(trailRetention));

  // update all walkers
  for (int i = 0; i < walkerCount; i++) {
    walkers[i].update(t);
  }

  // front layer (P3D) — sharp, near filaments
  pgFront.beginDraw();
  pgFront.background(0, 0);
  pgFront.hint(ENABLE_DEPTH_TEST);
  pgFront.camera(0, -90, 560, 0, 0, 0, 0, 1, 0);
  pgFront.rotateY(globalTheta + t * rotSpeed);
  pgFront.rotateX(0.12);
  pgFront.rotateZ(0.04);

  // LIGHTING: 1 ambient + 7 pointLight = exactly 8 (OpenGL hard limit)
  pgFront.ambientLight(18, 20, 26);

  float pulse = 0.5 + 0.5 * sin(t * 0.12);
  for (int lc = 0; lc < maxLights; lc++) {
    int idx = lightCarriers[lc];
    if (idx >= 0 && idx < walkerCount) {
      Walker w = walkers[idx];
      // STRONGER violet light intensity
      pgFront.pointLight(
        red(bioViolet) * pulse * (1.2 + random(0.8)),
        green(bioViolet) * pulse * (1.2 + random(0.8)),
        blue(bioViolet) * pulse * (1.8 + random(1.2)),
        w.pos.x, w.pos.y, w.pos.z
      );
    }
  }

  // draw front walkers in 3D
  pgFront.noFill();

  for (int i = 0; i < walkerCount; i++) {
    if (walkers[i].layer != 2) continue;

    float alpha = walkers[i].baseAlpha * random(0.78, 1.0);

    if (walkers[i].isCorrupted) {
      pgFront.stroke(255, alpha * 1.6);
      pgFront.strokeWeight(1.0);
    } else if (walkers[i].isLight) {
      pgFront.stroke(240, 235, 255, alpha * 1.4);
      pgFront.strokeWeight(0.9);
    } else if (walkers[i].isGlow) {
      // glow nodes get violet tint even in front layer
      pgFront.stroke(220, 210, 245, alpha * 1.2);
      pgFront.strokeWeight(0.7);
    } else {
      pgFront.stroke(205, 210, 220, alpha);
      pgFront.strokeWeight(0.6);
    }

    pgFront.beginShape();
    for (int k = 0; k < trailLength - 1; k++) {
      int idx = (walkers[i].tIndex + k) % trailLength;
      int next = (idx + 1) % trailLength;
      if (walkers[i].trail[idx] == null || walkers[i].trail[next] == null) continue;
      pgFront.vertex(walkers[i].trail[idx].x, walkers[i].trail[idx].y, walkers[i].trail[idx].z);
      pgFront.vertex(walkers[i].trail[next].x, walkers[i].trail[next].y, walkers[i].trail[next].z);
    }
    pgFront.endShape();
  }

  // calculate screen projections for ALL walkers
  for (int i = 0; i < walkerCount; i++) {
    projX[i] = pgFront.screenX(walkers[i].pos.x, walkers[i].pos.y, walkers[i].pos.z);
    projY[i] = pgFront.screenY(walkers[i].pos.x, walkers[i].pos.y, walkers[i].pos.z);
    projZ[i] = pgFront.screenZ(walkers[i].pos.x, walkers[i].pos.y, walkers[i].pos.z);
  }

  pgFront.endDraw();

  // back layer (P2D) — far filaments, creamy bokeh
  pgBack.beginDraw();
  pgBack.background(0, 0);
  pgBack.noStroke();
  pgBack.blendMode(BLEND);

  for (int i = 0; i < walkerCount; i++) {
    if (walkers[i].layer != 0) continue;

    float alpha = walkers[i].baseAlpha * random(0.6, 1.0) * 0.35;
    float sz = walkers[i].isCorrupted ? random(3.5, 6.0) : random(2.0, 4.5);

    // MORE violet in back layer
    float r = lerp(160, 205, random(1));
    float g = lerp(165, 210, random(1));
    float b = lerp(185, 225, random(1));
    if (walkers[i].isCorrupted || walkers[i].isGlow || random(1) > 0.70) {
      r = lerp(r, red(bioViolet), 0.40);
      g = lerp(g, green(bioViolet), 0.35);
      b = lerp(b, blue(bioViolet), 0.50);
    }

    pgBack.fill(r, g, b, alpha);
    pgBack.ellipse(projX[i], projY[i], sz, sz);

    pgBack.stroke(r, g, b, alpha * 0.6);
    pgBack.strokeWeight(0.4);
    for (int k = 0; k < trailLength - 1; k++) {
      int idx = (walkers[i].tIndex + k) % trailLength;
      int next = (idx + 1) % trailLength;
      if (walkers[i].trail[idx] == null || walkers[i].trail[next] == null) continue;
      float dx = walkers[i].trail[next].x - walkers[i].trail[idx].x;
      float dy = walkers[i].trail[next].y - walkers[i].trail[idx].y;
      pgBack.line(
        projX[i] - dx * 1.2, projY[i] - dy * 1.2,
        projX[i] + dx * 0.3, projY[i] + dy * 0.3
      );
    }
    pgBack.noStroke();
  }

  pgBack.filter(BLUR, backBlur);
  pgBack.endDraw();

  // mid layer (P2D) — atmospheric haze
  pgMid.beginDraw();
  pgMid.background(0, 0);
  pgMid.noStroke();
  pgMid.blendMode(BLEND);

  for (int i = 0; i < walkerCount; i++) {
    if (walkers[i].layer != 1) continue;

    float alpha = walkers[i].baseAlpha * random(0.75, 1.0) * 0.65;
    float sz = walkers[i].isCorrupted ? random(2.2, 4.0) : random(1.4, 2.8);

    // MORE violet in mid layer
    float r = lerp(185, 215, random(1));
    float g = lerp(190, 218, random(1));
    float b = lerp(205, 228, random(1));
    if (walkers[i].isGlow || random(1) > 0.70) {
      r = lerp(r, red(bioViolet), 0.45);
      g = lerp(g, green(bioViolet), 0.40);
      b = lerp(b, blue(bioViolet), 0.55);
    }

    pgMid.fill(r, g, b, alpha);
    pgMid.ellipse(projX[i], projY[i], sz, sz);

    pgMid.stroke(r, g, b, alpha * 0.8);
    pgMid.strokeWeight(0.5);
    for (int k = 0; k < trailLength - 1; k++) {
      int idx = (walkers[i].tIndex + k) % trailLength;
      int next = (idx + 1) % trailLength;
      if (walkers[i].trail[idx] == null || walkers[i].trail[next] == null) continue;
      float dx = walkers[i].trail[next].x - walkers[i].trail[idx].x;
      float dy = walkers[i].trail[next].y - walkers[i].trail[idx].y;
      pgMid.line(
        projX[i] - dx * 0.8, projY[i] - dy * 0.8,
        projX[i] + dx * 0.2, projY[i] + dy * 0.2
      );
    }
    pgMid.noStroke();
  }

  pgMid.filter(BLUR, midBlur);
  pgMid.endDraw();

  // glow pass (P2D) — MASSIVE violet halo
  pgGlow.beginDraw();
  pgGlow.background(0, 0);
  pgGlow.noStroke();
  pgGlow.blendMode(ADD);

  // glow from light carriers (7) — brightest cores
  for (int lc = 0; lc < maxLights; lc++) {
    int idx = lightCarriers[lc];
    if (idx < 0 || idx >= walkerCount) continue;
    float h = hField(walkers[idx].pos.x, walkers[idx].pos.y, walkers[idx].pos.z);
    float sz = random(14, 38) * (1.0 + h * 0.5);
    float alpha = random(30, 65) * random(0.8, 1.0);
    pgGlow.fill(red(bioViolet), green(bioViolet), blue(bioViolet), alpha);
    pgGlow.ellipse(projX[idx], projY[idx], sz, sz);
    pgGlow.fill(250, 250, 255, alpha * 0.30);
    pgGlow.ellipse(projX[idx], projY[idx], sz * 0.25, sz * 0.25);
  }

  // glow from glow nodes (280) — dense scattered violet
  for (int g = 0; g < glowNodeCount; g++) {
    int idx = glowNodes[g];
    if (idx < 0 || idx >= walkerCount) continue;
    float h = hField(walkers[idx].pos.x, walkers[idx].pos.y, walkers[idx].pos.z);
    float bio = noise(idx * 0.3, t * 0.05);
    float intensity = (h * 0.6) + (bio * 0.4) + (walkers[idx].isCorrupted ? 0.3 : 0);
    float sz = random(6, 22) * (1.0 + intensity * 0.8);
    float alpha = random(12, 35) * intensity * random(0.8, 1.0);

    pgGlow.fill(red(bioViolet), green(bioViolet), blue(bioViolet), alpha);
    pgGlow.ellipse(projX[idx], projY[idx], sz, sz);

    pgGlow.fill(240, 240, 255, alpha * 0.22);
    pgGlow.ellipse(projX[idx], projY[idx], sz * 0.35, sz * 0.35);
  }

  // extra ambient glow on high-H-field zones — fills ALL gaps
  for (int i = 0; i < walkerCount; i += 5) {
    float h = hField(walkers[i].pos.x, walkers[i].pos.y, walkers[i].pos.z);
    if (h > 0.35 && random(1) > 0.45) {
      float sz = random(14, 30) * h;
      float alpha = random(8, 20) * h;
      pgGlow.fill(red(bioViolet), green(bioViolet), blue(bioViolet), alpha);
      pgGlow.ellipse(projX[i], projY[i], sz, sz);
    }
  }

  // global H-field glow — violet washes over the whole structure
  for (int i = 0; i < walkerCount; i += 12) {
    float h = hField(walkers[i].pos.x, walkers[i].pos.y, walkers[i].pos.z);
    if (h > 0.25) {
      float sz = random(20, 45) * h;
      float alpha = random(4, 12) * h;
      pgGlow.fill(red(bioViolet), green(bioViolet), blue(bioViolet), alpha);
      pgGlow.ellipse(projX[i], projY[i], sz, sz);
    }
  }

  pgGlow.blendMode(BLEND);
  pgGlow.filter(BLUR, glowBlur);
  pgGlow.endDraw();

  // composite all layers
  image(pgBack, 0, 0);
  image(pgMid, 0, 0);
  image(pgFront, 0, 0);

  blendMode(ADD);
  tint(255, int(glowAlpha * 255));
  image(pgGlow, 0, 0);
  noTint();
  blendMode(BLEND);

  // export frame
  saveFrame("nodulo_001-####.png");

  frameCounter++;
}

// the underground is thinking.
