#!/usr/bin/python
"""This program is in the public domain.
As for the font, it was part of Linux core fonts
so I assume it's freely distributable."""
import pygame
from pygame.locals import *
from random import randint as rand
from sys import exit
from os import environ

class Ball:
  
  v_change = 0

  def __init__(self, xpos):
    
    size = (30,30)
    black = (0,0,0)
    white = (255,255,255)
    center = (size[0]/2, size[1]/2)
    rad = size[0]/2
    self.v = 400 + self.v_change # pixels per second

    self.image = pygame.Surface(size)
    self.image.fill(white)
    self.image.set_colorkey(white)
    pygame.draw.circle(self.image, black, center, rad)
    self.rect = self.image.get_rect()
    self.rect = self.rect.move(xpos, 0)

  def update(self, time):
    
    self.rect = self.rect.move(0, self.v*time)


class Player:
  
  def __init__(self):
    size = [30,30]
    black = [0, 0, 0]
    point_list = ( [0, size[1] ], [size[0]/2, 0], [size[0], size[1]], \
       [0, size[1] ])
    self.direction = 0
    self.right = 10
    self.left = -10
    self.width, height = pygame.display.get_surface().get_size() # screen size
    self.image = pygame.Surface(size).convert()
    self.image.fill([255,255,255])
    self.image.set_colorkey([255,255,255])
    self.rect = self.image.get_rect()
    pygame.draw.polygon(self.image, black, point_list)
    self.rect = self.rect.move(self.width/2, height-size[0]-1)

  def update(self):
    if self.direction > 0 and self.rect.right + self.right < self.width:
      self.rect = self.rect.move(self.right,0)
    elif self.direction < 0 and self.rect.left + self.left > 0:
      self.rect = self.rect.move(self.left,0)


class Game:

  def __init__(self):

    self.white = (255,255,255)
    self.black = (0,0,0)

    pygame.init()
    self.ss = (450, 450)
    environ['SDL_VIDEO_CENTERED'] = '1' # os library var, to center screen
    try:
      self.screen = pygame.display.set_mode(self.ss)
    except pygame.error:
      exit("Screen, could not be created, your computer sucks!")
    pygame.display.set_caption("Dodge Ball!")
    self.screen.fill(self.white)

    cont = self.load_menu()
    if cont:
      self.play()
    else:
      exit()

  def play(self):
    
    score = 0 # raises by 10 for each ball avoided
    balls = [] # To store all ball objects
    fallen_balls = 0

    player = Player()
    balls.append(Ball(self.ss[0]/2)) # First ball

    while 1:
      secs = self.clock.tick(50) / 1000.0

      for event in pygame.event.get():
        if event.type == QUIT:
          exit()
        if event.type == KEYDOWN:
          if event.key == K_LEFT:
            player.direction = -1
          if event.key == K_RIGHT:
            player.direction = 1
        if event.type == KEYUP and (event.key==K_LEFT or event.key == K_RIGHT):
          if not pygame.key.get_pressed()[K_LEFT] and\
              not pygame.key.get_pressed()[K_RIGHT]:
            player.direction = 0

      # Erase...Everything!
      self.screen.fill(self.white)
      for ball in balls:
        ball.update(secs)
      player.update()

      # Collision detection for ball with player...Game over!
      for ball in balls:
        if ball.rect.colliderect(player.rect):
          # Draw ball so they can see it hit them.
          for b in balls:
            self.screen.blit(b.image, b.rect)
            pygame.display.update(b.rect)
          self.screen.fill(self.white)
          # All these updates are for visual sake. Take one out if your
          # computer sux0rz.
          # Tell them GAMEOVER and score. Then load menu.
          print 'Gameover!'
          print 'Score = ', score
          # Maybe print it out to the screen someday when I become less lazy.
          
          pygame.display.update()
          cont = self.load_menu()
          if cont:
            Ball.v_change = 0 # Reset ball speed
            self.play()
          else:
            exit()

      # Collision detection for ball with ground
      ball = balls[0]
      if ball.rect.y > self.ss[1]:
        score += 10 + 10*(fallen_balls/10)
        fallen_balls += 1
        if fallen_balls % 10 == 0:
          Ball.v_change += 100 # Speed up the balls
        balls = []
        ball = Ball(player.rect.x)
        balls.append(ball) # Regular ball
        for _ in range(fallen_balls/10): # Add a new ball per ten
          # Give it a random x somewhat close to the first one
          center = player.rect.x
          # Choose a random side.
          if rand(1,2) == 1:
            side = 'left'
          else:
            side = 'right'
          
          if side == 'right':
            try:
              rand_x = rand(center+80,self.ss[0]-(self.ss[0]-center)/4)
            except ValueError: # too far right
              side = 'left'
          if side == 'left':
            try:
              rand_x = rand(center/4, center-30)
            except ValueError: # too far left? Odd bug.
              rand_x = 0
            if rand_x < 30:
              rand_x += rand(50, 300)
          balls.append(Ball(rand_x))
  
      # Draw the player
      self.screen.blit(player.image, player.rect)
      # Draw the balls
      for ball in balls:
        self.screen.blit(ball.image, ball.rect)

      pygame.display.update()

  def draw_text(self, text, font, pos):
    t_im = font.render(text, 1, self.black)
    t_rect = t_im.get_rect()
    t_rect = t_rect.move(pos)
    self.screen.blit(t_im, t_rect)
    pygame.display.update(t_rect)

  def load_menu(self):
    # Dodge Ball - By Jach
    #
    # (0) Play
    #     Quit

    pointer = pygame.Surface( (30,30) )
    pointer.fill(self.white)
    pygame.draw.circle(pointer, self.black, (15,15), 15)

    font = pygame.font.Font('cour.ttf', 20)
    font_height = font.get_linesize()
    title_width = font.size('Dodge Ball - By Jach')[0]
    width, height = self.ss
    self.draw_text('Dodge Ball - By Jach', font,\
        (width/2 - title_width/2, font_height + 10) )
    font = pygame.font.Font('cour.ttf', 18)
    font_height = font.get_linesize()
    self.draw_text('Play', font, (width/6, height/2) )
    self.draw_text('Quit', font, (width/6, height/2 + 2*font_height) )
    
    pointer_pos = (width/6 - 40, (height / 2, height/2 + 2*font_height))
    # Possible pointer positions
    selected = 'play'
    self.screen.blit(pointer, (pointer_pos[0], pointer_pos[1][0]))

    self.clock = pygame.time.Clock()
    while 1:
      self.clock.tick(10)

      # ugly event loop
      for event in pygame.event.get():
        if event.type == QUIT:
          return 0
        if event.type == KEYDOWN:
          if (event.key == K_UP or event.key == K_DOWN) and selected == 'play':
            self.screen.fill(self.white,\
                (pointer_pos[0], pointer_pos[1][0],30,30))
            self.screen.blit(pointer, (pointer_pos[0], pointer_pos[1][1]))
            selected = 'quit'
          elif (event.key ==K_UP or event.key == K_DOWN) and selected== 'quit':
            self.screen.fill(self.white,\
                (pointer_pos[0], pointer_pos[1][1],30,30))
            self.screen.blit(pointer, (pointer_pos[0], pointer_pos[1][0]))
            selected = 'play'
          if event.key == K_RETURN:
            if selected == 'play':
              return 1
            else:
              return 0

      pygame.display.update()

if __name__ == '__main__':
  g = Game()
