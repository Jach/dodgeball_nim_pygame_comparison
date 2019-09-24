discard """
This file is in the public domain.
Depends on SDL2. Install Nimble, then run:
  nim install sdl2
to grab the dependency.
To build and run:
  make release
  ./dodge
"""

import sdl2, sdl2/gfx
import math
import random


# Rect procs to make it a bit saner to work with the types and SDL's default rect...
proc move_ip*(self: var Rect, x, y: int) {.inline.} =
  self.x += x.cint
  self.y += y.cint

proc set_size*(self: var Rect, w, h: int) {.inline.} =
  self.w = w.cint
  self.h = h.cint

proc get_rect*(text: TexturePtr): Rect =
  var w, h: cint
  text.queryTexture(nil, nil, addr(w), addr(h))
  result = (0.cint, 0.cint, w.cint, h.cint)

proc right*(self: var Rect): int {.inline.} =
  self.x + self.w

proc left*(self: var Rect): int {.inline.} =
  self.x

proc top*(self: var Rect): int {.inline.} =
  self.y

proc bottom*(self: var Rect): int {.inline.} =
  self.y + self.h

proc colliderect*(self, other: var Rect): bool {.inline.} =
  ((self.x >= other.x and self.x < other.x + other.w) or
   (other.x >= self.x and other.x < self.x + self.w)) and
    ((self.y >= other.y and self.y < other.y + other.h) or
     (other.y >= self.y and other.y < self.y + self.h))

# End of Rect procs

# Overloads to make working with color-tuples saner...
proc fill(screen: RendererPtr, color: (int, int, int)) {.inline.} =
  screen.setDrawColor(color[0].uint8, color[1].uint8, color[2].uint8, 255.uint8)
  screen.clear()

proc fill(surf: SurfacePtr, color: (int, int, int)) =
  let color = mapRGB(surf.format, color[0].uint8, color[1].uint8, color[2].uint8)
  var rect:Rect = (0.cint, 0.cint, surf.w, surf.h)
  surf.fillRect(addr(rect), color)
# End of overloads

# Graphics overloads
# This was incredibly more complicated to get working than I thought it should be!
proc drawFilledCircle(screen: RendererPtr, color: (int, int, int), center: (int, int), radius: int) =
  discard screen.filledCircleRGBA(center[0].int16, center[1].int16, radius.int16, color[0].uint8, color[1].uint8, color[2].uint8, 255)

# cool template to make this cast prettier...
# note we need the addr x[0] for seqs, addr x would work for arrays
template `:-/` (x: untyped): untyped = cast[ptr type(x[0])](addr x[0])
proc drawFilledPolygon(screen: RendererPtr, color: (int, int, int), point_list: openarray[array[2, int]]) =
  var xs, ys: seq[int16]
  xs = @[]
  ys = @[]
  let
    points = point_list.len.cint
  for point in point_list:
    xs.add(point[0].int16)
    ys.add(point[1].int16)
  discard screen.filledPolygonRGBA(:-/xs, :-/ys, points, color[0].uint8, color[1].uint8, color[2].uint8, 255)

# Nice helper fn
proc getKeyValue(key: KeyboardEventPtr): cint =
  return key.keysym.sym

var
  window: WindowPtr
  screen: RendererPtr
  fpsman: FpsManager
  event = sdl2.defaultEvent

const
  SCREEN_WIDTH = 450
  SCREEN_HEIGHT = 450
  WHITE = (255, 255, 255) # WEIRD type conversion issues with containers.
  BLACK = (0, 0, 0)
  RED = (255,0,0)
  FPS = 50

# Ball 'class'
var
  ball_v_change = 0.0
const
  ball_rad = 15 # interesting note: if these are inner lets, they aren't int literals
  ball_diam = ball_rad*2
type
  Ball = ref object of RootObj
    v: float # pixels per second
    image: TexturePtr
    rect: Rect

# make the ball texture once (interesting render artifacts when making lots -- e.g. transparency
# goes away...)
var ball_image: TexturePtr = nil
proc getBallImage(): TexturePtr =
  if ball_image != nil:
    return ball_image
  ball_image = screen.createTexture(SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, ball_diam, ball_diam)
  ball_image.setTextureBlendMode(BLENDMODE_BLEND)
  screen.setRenderTarget(ball_image)
  screen.drawFilledCircle(RED, (ball_rad, ball_rad), ball_rad-1)
  screen.setRenderTarget(nil)
  return ball_image

proc newBall(xpos:int): Ball =
  # Create a red ball with initial x position specified by xpos
  new(result)
  result.v = 300 + ball_v_change
  result.image = getBallImage()

  result.rect = result.image.get_rect()
  result.rect.move_ip(xpos, 0)

proc update(self: Ball, dt: float) =
  self.rect.move_ip(0, int(self.v*dt))

proc render(self: Ball, screen: RendererPtr) =
  screen.copy(self.image, nil, addr(self.rect))


# Player 'class'
type
  Direction = enum
    LEFT,
    STILL,
    RIGHT
  Player = ref object of RootObj
    direction: Direction
    shift_left: int
    shift_right: int
    image: TexturePtr
    rect: Rect

proc newPlayer(): Player =
  new(result)
  result.direction = STILL
  result.shift_left = -13
  result.shift_right = 13

  let
    w = 30
    h = 30
    point_list = [ [0, h], [int(w/2), 0], [w, h],  [0, h] ]
  result.image = screen.createTexture(SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, w.cint, h.cint)
  # create 'triangle'...
  result.image.setTextureBlendMode(BLENDMODE_BLEND)

  screen.setRenderTarget(result.image)
  screen.drawFilledPolygon(BLACK, point_list)
  screen.setRenderTarget(nil)

  result.rect = result.image.get_rect()
  result.rect.move_ip(int(SCREEN_WIDTH/2), SCREEN_HEIGHT - h - 1)

proc update(self: Player) =
  if self.direction == RIGHT and self.rect.right + self.shift_right < SCREEN_WIDTH:
    self.rect.move_ip(self.shift_right,0)
  elif self.direction == LEFT and self.rect.left + self.shift_left > 0:
    self.rect.move_ip(self.shift_left,0)

proc render(self: Player, screen: RendererPtr) =
  screen.copy(self.image, nil, addr(self.rect))

# GAME

proc play() =
  var
    score = 0.0
    balls: seq[Ball] = @[]
    fallen_balls = 0
    player = newPlayer()

  balls.add(newBall(int(SCREEN_WIDTH/2))) # first ball

  var run = true
  while run:
    fpsman.delay()
    let dt = fpsman.getFrameRate() / 1000

    while pollEvent(event):
      if event.kind == QuitEvent or (event.kind == KeyDown and getKeyValue(event.key) == K_Escape):
        run = false
        break
      if event.kind == KeyDown:
        if event.key.getKeyValue() == K_Left:
          player.direction = LEFT
        if event.key.getKeyValue() == K_Right:
          player.direction = RIGHT
      if event.kind == KeyUp and (event.key.getKeyValue() == K_Left or event.key.getKeyValue() == K_Right):
        if getKeyboardState()[SDL_SCANCODE_LEFT.ord] == 0 and getKeyboardState()[SDL_SCANCODE_RIGHT.ord] == 0:
          player.direction = STILL


    screen.fill(WHITE)

    for ball in balls:
      ball.update(dt)
    player.update()

    # collision detection for ball with player
    for ball in balls:
      if ball.rect.colliderect(player.rect):
        echo("You got hit. Final score: ", score)
        echo("Reseting.")
        score = 0
        fallen_balls = 0
        ball_v_change = 0.0
        ball.rect.move_ip(0, 500) # move it off the screen now so it won't collide again

    # collision detection for ball with ground
    let
      ball = balls[0]
    if ball.rect.y > SCREEN_HEIGHT:
      score += 10 + 10*(fallen_balls/10)
      fallen_balls += 1
      if fallen_balls mod 10 == 0:
        ball_v_change += 80 # speed up balls
      balls = @[] # old balls should get GC'd...
      balls.add(newBall(player.rect.x)) # 'regular' ball first
      for _ in 0..int(fallen_balls/10)-1: # new ball per ten
        let center = player.rect.x
        var side = "left"
        var rand_x = 0
        if random(2) == 1:
          side = "right"
        if side == "right":
          let
            left_bound = center + 80
            right_bound = SCREEN_WIDTH - int((SCREEN_WIDTH - center)/4)
          if left_bound < right_bound:
            rand_x = left_bound + random(right_bound-left_bound)
          else:
            side = "left" # too far right
        if side == "left":
          if int(center/4) < center-30:
            rand_x = 0
          else:
            var diff = center-30 - int(center/4)
            if diff < 0:
              diff = -random(-diff)
            else:
              diff = random(diff)
            rand_x = int(center/4) + diff
          if rand_x < 30:
            rand_x += 50 + random(300-50)
        balls.add(newBall(rand_x))

    # render player, then balls at the last
    player.render(screen)
    for ball in balls:
      ball.render(screen)

    screen.present()


proc main() =
  discard sdl2.init(INIT_EVERYTHING)

  window = createWindow("Dodge Ball!",
    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
    SCREEN_WIDTH, SCREEN_HEIGHT,
    SDL_WINDOW_SHOWN)
  screen = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)

  fpsman.init()
  fpsman.setFrameRate(FPS)

  screen.fill(WHITE)
  play()

  destroy screen
  destroy window

main()
