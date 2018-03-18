pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- ~bugbugboss~
-- adam emery

shake = 0
exp = {}
splats = {}
wave = 1
stars = {}
lives = 4
win = false
wave_animate = nil

------ bullet ------

bullet = {x=0,y=0,vx=0,vy=-4}


function bullet:new(o)
	self.__index = self
	local new = setmetatable(o or {}, self)
	add(bullets, new)
	return new
end

function bullet:draw()
	sspr(8*3,0,1,5,self.x,self.y)
end

function bullet:update()
	self:move()
end

function bullet:move()
	self.x+=self.vx
	self.y+=self.vy
	self:checkhit()
	if self.y < 0 or self.y > 126 then
		del(bullets,self)
	elseif self.x < 0 or self.x > 126 then
		del(bullets,self)
	end
	
end

function bullet:checkhit() end

------ player bullet -----
laser = bullet:new{}

function laser:checkhit()
	for e in all(enemies) do
		if e.boss then
			x_dist = (self.x - e.x-8)^2
			y_dist = (self.y - e.y-8)^2

			dist = sqrt(x_dist + y_dist)

			if dist < 8 then
				e:hit()
				del(bullets,self)
				return
			end
		else
			x_dist = (self.x - e.x-4)^2
			y_dist = (self.y - e.y-4)^2

			dist = sqrt(x_dist + y_dist)

			if dist < 6 then
				explode(e.x+4,e.y,2,10)
				splat(e.x,e.y)
				del(enemies,e)
				del(bullets,self)
				sfx(0)
				shake =4
				return
			end
		end 
	end
end

------ slime bullet ------

slime = bullet:new{vy=3}

function slime:draw()
	sspr(8*3+1,0,3,4,self.x,self.y)
end

function slime:checkhit()
	if player then
		x_dist = (self.x - player.x-4)^2
		y_dist = (self.y - player.y-4)^2

		dist = sqrt(x_dist + y_dist)

		if dist < 4 then
			explode(player.x+4,player.y,8,7)
	 		explode(player.x+4,player.y,4,10)
			player = nil
			shake = 20
			del(bullets,self)
			sfx(1)
			music(-1)
			restart()
		end
	end
end

------ plasma bullet------ 

plasma = slime:new{vy=1}

function plasma:draw()
	sspr(8*3+1,4,3,4,self.x,self.y)
end

function plasma:update()
	self:move()
	if abs(self.sx - self.x) > 15 then
		self.vx = -self.vx
	end
end

------ slime ball -------

sball = slime:new{vy=1,f=0}

function sball:draw()
	if self.f >= 2 then
		sspr(8*3+4,0,3,3,self.x,self.y)
	else
		sspr(8*3+4,3,3,3,self.x,self.y)
	end
end

function sball:update()
	self:move()

	if self.y > 70 then
		del(bullets,self)
		slime:new({x=self.x,y=self.y,vy = 2})
		slime:new({x=self.x+3,y=self.y,vx = .2,vy = 2})
		slime:new({x=self.x-3,y=self.y,vx =-.2,vy = 2})
		sfx(6)
	end

	self.f+=1
	if self.f>4 then
		self.f=0
	end
end

------ ship ------

ship = {x=60,y=120,f=0,cool=0}

function ship:new(o)
	self.__index = self
	return setmetatable(o or {}, self)
end

function ship:fire()
	if self.cool <= 0 and not wave_animate and not win then
		laser:new({x=self.x+3,y=self.y})
		self.cool = 10
		sfx(2)
	end
end

function ship:update()
	if btn(5) then
		self:fire()
	end

	if btn(0) then
		self.x -=2
		if self.x < 0 then
			self.x = 0
		end
	end
	
	if btn(1) then
		self.x += 2
		if self.x > 120 then
			self.x = 120
		end
	end

	if self.cool>0 then
		self.cool-=1
	end
	
	self.f+=1
	if self.f>6 then
		self.f=0
	end
end

function ship:draw()
	if self.f >= 3 then
		spr(1,self.x,self.y)
	else
		spr(2,self.x,self.y)
	end

	if not win then
		for i=0,lives-1 do
			spr(17,1 + 4*i,1)
		end
	end
end

------ enemy -----

enemy = {x=0,y=0,f=0,behaviors={}}

function enemy:new(o)
	self.__index = self
	local new = setmetatable(o or {}, self)
	add(enemies, new)
	return new
end

function enemy:super()
	return enemy
end

function enemy:update()
	foreach(self.behaviors,function(b) 
		if b and costatus(b) != 'dead' then
		    coresume(b)
		else
	  		del(self.behaviors, b)
	  	end
	end)
end

function enemy:fly(x,y,time,delay)
	local behav = function()
		for w=1,delay,1 do yield() end
			local xpt = (x-self.x) * 1.0/time
			local ypt = (y-self.y) * 1.0/time
		for i=1,time,1 do
			self.x += xpt
			self.y += ypt
			yield()
		end
	end
	add(self.behaviors,cocreate(behav))
end

function enemy:moveby(x,y,time,delay)
	local behav = function()
		for w=1,delay,1 do yield() end
		local xpt = x * 1.0/time
		local ypt = y * 1.0/time
		for i=1,time,1 do
			self.x += xpt
			self.y += ypt
			yield()
		end
	end
	add(self.behaviors,cocreate(behav))
end

function enemy:flycircle(time,delay)
	local behav = function()
		for w=1,delay,1 do yield() end
		for i=1,time,1 do
			if i < time/4.0 then 
				self.x += 30*1/time
				self.y += 30*1/time
			elseif i < time/2.0 then
				self.x -= 30*1/time
				self.y += 30*1/time
			elseif i < time*3.0/4.0 then
				self.x -= 30*1/time
				self.y -= 30*1/time
			else
				self.x += 30*1/time
				self.y -= 30*1/time
			end
			
			yield()
		end
	end
	add(self.behaviors,cocreate(behav))
end

function enemy:loopinto(x,y,left)
	dir = 1
	if left then
		self:fly(20,30,60,0)
	else
		dir = -1
		self:fly(106,30,60,0)
	end
	self:moveby(10*dir,0,5,65)
	self:moveby(5*dir,-5,5,70)

	self:moveby(0*dir,-10,5,75)
	self:moveby(-5*dir,-5,5,80)

	self:moveby(-10*dir,0,5,85)
	self:moveby(-5*dir,5,5,90)

	self:moveby(0*dir,10,5,95)
	self:moveby(5*dir,5,5,100)

	self:moveby(10*dir,0,5,105)
	self:moveby(5*dir,-5,5,110)

	self:moveby(0*dir,-10,5,115)
	self:moveby(-5*dir,-5,5,120)


	self:fly(x,y,60,125)
end

------ bug ------

bug = enemy:new()

function bug:fire()
	slime:new({x=self.x+3,y=self.y})
	sfx(3)
end

function bug:update()
	self:super():update()
	self.f+=1
	if self.f>30 then
		self.f=0
		if rnd(100)>60 and not wave_animate then
			self:fire()
		end
	end
end

function bug:draw()
	if self.f >= 15 then
		spr(4,self.x,self.y)
	else
		spr(5,self.x,self.y)
	end
end


------ red bug -------
rbug = bug:new()

function rbug:draw()
	if self.f >= 15 then
		spr(6,self.x,self.y)
	else
		spr(7,self.x,self.y)
	end
end

function rbug:fire()
	plasma:new({x=self.x+3,y=self.y,sx=self.x+3,vx=2})
	sfx(4)
end


------ yellow bug -------
ybug = bug:new()

function ybug:draw()
	if self.f >= 15 then
		spr(8,self.x,self.y)
	else
		spr(9,self.x,self.y)
	end
end

function ybug:fire()
	sball:new({x=self.x+3,y=self.y})
	sfx(5)
end

------ boss -------

boss = enemy:new{boss=true, health=40}

function boss:draw()
	if self.f >= 15 then
		spr(10,self.x,self.y,2,2)
	else
		spr(12,self.x,self.y,2,2)
	end

	if self.health > 0 then

		rect(15, 1, 111, 5, 5)
		rectfill(16, 2, 16 + self.health/boss.health *94, 4, 8)
	end
end

function boss:update()
	self:super():update()
	self.f+=1
	if self.f>30 then
		self.f=0
	end
	if #self.behaviors <= 0 and player then
		local c  = flr(rnd(6))

		while self.lastcommand == c do
			c  = flr(rnd(6))
		end

		self.lastcommand = c

		if c == 0 then
			self:move_right()
	    elseif c == 1 then
			self:move_left()
		elseif c == 2 then
			self:fire_at_player()
		elseif c == 3 then
			self:lay_mines()
		elseif c == 4 then
			self:fire_plasma()
		else
			self:move_center()
		end
	end
end

function boss:hit()
	self.health -=1
	if self.health <= 0 then
		self:die()
		sfx(8)
	else 
		sfx(9)
	end
end

function boss:die()
	explode(self.x+8,self.y+8,3,7)
	explode(self.x+8,self.y+8,2,10)

	explode(self.x,self.y,2,7)
	explode(self.x+7,self.y,1,7)

	explode(self.x+4,self.y+6,2,10)

	splat(self.x,self.y)
	splat(self.x+8,self.y)
	splat(self.x+1,self.y+8)
	splat(self.x+7,self.y+8)


	shake = 30
	del(enemies,self)
	victory_animate = cocreate(victory)
end


function boss:move_right()
	self:fly(110,10,60,0)
end

function boss:move_center()
	self:fly(60,30,60,0)
end

function boss:move_left()
	self:fly(4,10,60,0)
end

function boss:fire_at_player()
	if player then
		local behav = function()
			for w=1,5,1 do 
				for w=1,6,1 do yield() end
				local dx = (self.x+8) - (player.x+4 + rnd(20)-10)
				local dy = (self.y+8) - (player.y+4 + rnd(20)-10)
				local angle = atan2(dx,dy)

				local xmag = cos(angle) * -3
				local ymag = sin(angle) * -3
				slime:new({x=self.x+8,y=self.y+8,vx=xmag, vy=ymag})
				sfx(3)
				yield()
			end
		end
		add(self.behaviors,cocreate(behav))
	end
end

function boss:lay_mines()
	self:fly(4,10,40,0)
	self:fly(110,10,60,40)

	local behav = function()
		for w=1,40,1 do yield() end

		for w=1,60,1 do 
			if w % 6 == 0 then
				if flr(rnd(2)) == 0 then
					sball:new({x=self.x+8,y=self.y+8})
					sfx(3)
				end
			end
			yield()
		end
	end
	add(self.behaviors,cocreate(behav))
end

function boss:fire_plasma()
	self:fly(90,30,20,0)
	self:fly(60,10,20,20)
	self:fly(30,30,20,40)

	local behav = function()
		for i=1,3,1 do
			for w=1,20,1 do yield() end
			plasma:new({x=self.x+8,y=self.y+8,sx=self.x+3,vx=2})
		end
	end
	add(self.behaviors,cocreate(behav))
end

------ globals -------

bullets = {}
enemies = {}
player = nil
cor = nil

------ game code -------

function _init()
	create_stars()
	show_title()
end

function restart()
	if lives > 0 then
		cor = nil
		win = false
		bullets = {}
		enemies = {}
		enemy.behaviors ={}
		player = ship:new()
		wave -=1
		lives -=1
		increasewave()
	else
		lose()
		wave = 1
		lives = 4
	end
end

function splat(x,y)
	animation = function()
		r = rnd(2)
		yield()
		yield()
		spr(20+r,x,y)
		yield()
		spr(20+r,x,y)
		yield()
		spr(36+r,x,y)
		yield()
		spr(36+r,x,y)
		yield()
		spr(52+r,x,y)
		yield()
		spr(52+r,x,y)
	end
	add(splats,cocreate(animation))
end

function victory()

	for w=1,60,1 do yield() end
	win = true

	message1 = "you have saved the galaxy"
	message2 = "from certain doom by the"
	message3 = "the swarms of evil bugs!"
	message4 = "and their big evil boss!"
	message5 = "good job."

	for w=1,60,1 do
			print("victory!!!",50,50,7)
			yield() 
	end

	for w=1,40,1 do
			print("victory!!!",50,50-w,7)
			yield() 
	end

	for w=1,60,1 do
			print("victory!!!",50,10,7)

			print(sub(message1, 1,#message1*w/60),15,50,7)
			yield() 
	end

	for w=1,60,1 do
			print("victory!!!",50,10,7)
			print(message1,15,40,7)

			print(sub(message2, 1,#message2*w/60),15,50,7)
			yield() 
	end

	for w=1,60,1 do
			print("victory!!!",50,10,7)
			print(message1,15,30,7)
			print(message2,15,40,7)

			print(sub(message3, 1,#message3*w/60),15,50,7)
			yield() 
	end

	for w=1,60,1 do
			print("victory!!!",50,10,7)
			print(message1,15,20,7)
			print(message2,15,30,7)
			print(message3,15,40,7)

			print(sub(message4, 1,#message4*w/60),15,50,7)
			yield() 
	end

	for w=1,300,1 do
			print("victory!!!",50,10,7)
			print(message1,15,20,7)
			print(message2,15,30,7)
			print(message3,15,40,7)
			print(message4,15,50,7)

			print(sub(message5, 1,#message5*w/60),50,70,7)
			yield() 
	end


	show_title()
end

function increasewave()
	music(-1)
	wave += 1
	animation = function()
		sfx(13)
		for w=1,60,1 do
			if not game_over then
				print("wave " .. wave,50,50,7)
			end

			yield() 
		end
		music(0)
		spawn()
	end

	if wave < 10 then
	  wave_animate = cocreate(animation)
	elseif wave == 10 then
		animation = function()
		for w=1,30,1 do
			print("wave",36,50,7)
			yield() 
		end
		for w=1,30,1 do
			print("wave.",36,50,7)
			yield() 
		end
		for w=1,30,1 do
			print("wave..",36,50,7)
			yield() 
		end
		for w=1,30,1 do
			print("wave...",36,50,7)
			yield() 
		end

		spawnboss()

		for w=1,60,1 do
			ox,oy = rnd(4) - 2, rnd(4) - 2
			print("wave... boss!!!",36+ox,50+oy,7)
			yield() 
		end
		

		for w=1,30,1 do yield() end
		
	end

	wave_animate = cocreate(animation)
	end
end


function spawnboss()
	b = boss:new({x=100, y = 126})

	sfx(7)
	b:fly(50,60,30,0)
	b:fly(40,30,30,30)
	b:fly(58,15,30,60)

end


  	if title_screen and costatus(title_screen) != 'dead' then
    	coresume(title_screen)
  	else
    	title_screen = nil
  	end

function show_title()
	wave = 1
	player = nil 
	enemies = {}
	bullets = {}
	animation = function()
		for w=1,10,1 do
			sspr(0, 32, 40, 16, 124 - 100*w/10 , 20)
			yield() 
		end

		for w=1,4,1 do
			sspr(0, 32, 40, 16, 24 , 20, 40 - w*2,16)
			yield() 
		end

		for w=1,4,1 do
			sspr(0, 32, 40, 16, 24 , 20, 36 + w*2,16)
			yield() 
		end

		for w=1,10,1 do
			sspr(0, 32, 40, 16, 24, 20)
			sspr(0, 32, 40, 16, 166 - 100*w/10, 22)
			yield() 
		end

		for w=1,4,1 do
			sspr(0, 32, 40, 16, 24, 20)
			sspr(0, 32, 40, 16, 66, 22, 40 - w*2,16)
			yield() 
		end

		for w=1,4,1 do
			sspr(0, 32, 40, 16, 24, 20)
			sspr(0, 32, 40, 16, 66, 22, 40 - w*2,16)
			yield() 
		end

		count = 0
		zoom = 10
		while true do
			sspr(0, 32, 40, 16, 24, 20)
			sspr(0, 32, 40, 16, 66, 22)
			sspr(40, 32, 48, 16, 42 -24*(zoom-1), 46-8*(zoom-1),48*zoom,16*zoom)
			-- sspr(40, 32, 48, 16, 42, 46)
			yield() 

			if count < 20 then
				print("press x",50,90,7)
			elseif count >= 40 then
				count = 0
			end
			count+=1
			if zoom > 1 then
				zoom -=1
			end
		end
	end
	title_screen = cocreate(animation)
end



function start_game()
	sfx(15)
	animation = function()
		count = 0

		for w=1,44,1 do
			sspr(0, 32, 40, 16, 24, 20)
			sspr(0, 32, 40, 16, 66, 22)
			sspr(40, 32, 48, 16, 42, 46,48,16)
			yield() 

			if count < 20 then
				print("press x",50,90,7)
			elseif count >= 40 then
				count = 0
			end
			count+=1
		end

		for w=1,44,1 do
			sspr(0, 48, 40, 16, 24, 20)
			sspr(0, 48, 40, 16, 66, 22)
			sspr(40, 48, 48, 16, 42, 46,48,16)
			yield() 

			if count < 20 then
				print("press x",50,90,7)
			elseif count >= 40 then
				count = 0
			end
			count+=1
		end

		for w=1,44,1 do
			sspr(0, 64, 40, 16, 24, 20)
			sspr(0, 64, 40, 16, 66, 22)
			sspr(40, 32, 48, 16, 42, 46,48,16)
			yield() 

			if count < 20 then
				print("press x",50,90,7)
			elseif count >= 40 then
				count = 0
			end
			count+=1
		end
		restart()
	end
	title_screen = cocreate(animation)
end

function lose()
	sfx(14)
	animation = function()
		for w=1,180,1 do
			print("game over",47,50,7)
			yield() 
		end
		show_title()
	end
	game_over = cocreate(animation)
end

function spawn()
	if wave == 2 or wave == 6 or wave == 9 then
		for i=20,0,-1 do
			if i%10 == 0 then
				local b,b2 = nil,nil
				if wave == 2 then
				  b = bug:new({x=-10, y = 50})
				  b2 = bug:new({x=136, y = 50})
				elseif wave == 6 then
				  b = rbug:new({x=-10, y = 50})
				  b2 = rbug:new({x=136, y = 50})
				else
				  b = ybug:new({x=-10, y = 50})
				  b2 = ybug:new({x=136, y = 50})
				end
				b:loopinto(i*2+2,10, true)
				b2:loopinto(118-i*2,10,false)
			end
	    	yield()
	  	end

		for i=20,0,-1 do
			if i%10 == 0 then
				local b,b2 = nil,nil
				if wave == 9 and i==10 then
				  b = rbug:new({x=-10, y = 50})
				  b2 = rbug:new({x=136, y = 50})
				else
				  b = bug:new({x=-10, y = 50})
				  b2 = bug:new({x=136, y = 50})
				end
				b:loopinto(i*2+2,30, true)
				b2:loopinto(118-i*2,30,false)
			end
	    	yield()
	  	end
    end


    if wave == 3 or wave == 5 or wave == 8 then
    	for xgrid=0,2,1 do
    		b = bug:new({x=xgrid*50+ 10, y = -10})
    		b:fly(xgrid*50 + 10,10,60,0)

    		b2 = bug:new({x=xgrid*50+ 10, y = -10})
    		b2:fly(xgrid*50 + 10,25,60,0)

    		b3 = bug:new({x=xgrid*50+ 10, y = -10})
    		b3:fly(xgrid*50 + 10,40,60,0)
    	end

    	for xgrid=0,1,1 do

	    	local b = nil
			if wave == 3 then
			  b = bug:new({x=xgrid*50+36, y = -10})
			elseif wave == 5 then
			  b = rbug:new({x=xgrid*50+36, y = -10})
			else
			  b = ybug:new({x=xgrid*50+36, y = -10})
			end
    		b:fly(xgrid*50 + 36,10,100,0)

    		b2 = bug:new({x=xgrid*50+ 36, y = -10})
    		b2:fly(xgrid*50 + 36,25,100,0)

    	end
   	end

    if wave == 1 or wave == 4 or wave == 7 then
    	for xgrid=0,2,1 do
    		b = bug:new({x=xgrid*18, y = -10})
    		b:fly(xgrid*18,15*xgrid+10,60,0)

    		b2 = bug:new({x=120 - xgrid*18, y = -10})
    		b2:fly(120 - xgrid*18,15*xgrid+10,60,0)
    	end

    	local b3 = nil
		if wave == 1 then
		  b3 = bug:new({x=60, y = -10})
		elseif wave == 4 then
		  b3 = rbug:new({x=60, y = -10})
		else
		  b3 = ybug:new({x=60, y = -10})
		end
    	b3:fly(60,25,100,60)
   	end
end


function create_stars()
	stars = {}
	for i=1,30 do
		local s = {}
		s.x = rnd(127)
		s.y = rnd(127)
		s.dy = 0.5 + (rnd(70) * 0.01)
		if s.dy>1.45 then
			s.dy=4
		end
		if s.dy < 1.2 then
			s.col=1
 		else
 			s.col=7
		end
		add(stars,s)
	end
end

function update_stars()
	for s in all(stars) do
		s.y+=s.dy
		if s.y > 127 then
			s.y=-10
			s.x=rnd(127)
		end
	end
end

function draw_stars()
	for s in all(stars) do
	 sy2=s.y-(s.dy)*2
	 -- c=s.col
	 line(s.x,s.y,s.x,sy2,1)
	end
end

function explode(x, y, ttl, col)
  e = {}
  e.x = x
  e.y = y
  e.ttl = ttl
  e.col = col
  add(exp, e)
end

function _update()
	update_stars()

	if title_screen then
		if btn(5) then
			start_game()
		end
	elseif #enemies <= 0 and not wave_animate and not game_over and wave < 10 then
		increasewave()
	end
	for e in all(exp) do
		e.ttl-=1
		if (e.ttl <= 0) then
			del(exp,e) 
		end
	end
	if player then
		player:update()
	end
	foreach(bullets, function(obj) obj:update() end)
	foreach(enemies, function(obj) obj:update() end)

	if cor and costatus(cor) != 'dead' then
    	coresume(cor)
  	else
    cor = nil
  end
end

function _draw()
	cls(0)
	if (shake > 0) then
		camera(rnd(4) - 2, rnd(4) - 2)
		shake-=1
	else
		camera(0,0)
	end
	draw_stars()
	foreach(bullets, function(obj) obj:draw() end)
	foreach(enemies, function(obj) obj:draw() end)
 	if player then
 		player:draw()
 	end

 	foreach(splats,function(s) 
		if s and costatus(s) != 'dead' then
		    coresume(s)
		else
	  		del(splats, s)
	  	end
	end)

	if wave_animate and costatus(wave_animate) != 'dead' then
    	coresume(wave_animate)
  	else
    	wave_animate = nil
  	end

  	if victory_animate and costatus(victory_animate) != 'dead' then
    	coresume(victory_animate)
  	else
    	victory_animate = nil
  	end

  	if game_over and costatus(game_over) != 'dead' then
    	coresume(game_over)
  	else
    	game_over = nil
  	end

  	if title_screen and costatus(title_screen) != 'dead' then
    	coresume(title_screen)
  	else
    	title_screen = nil
  	end


	-- print(stat(7))
 -- 	print(stat(0))
 -- 	print(stat(1))
 	for e in all(exp) do
		circfill(e.x, e.y, e.ttl * 2, e.col)
	end

end

__gfx__
000000000007000000070000a0303b30000000000000000000000000000000000004400000044000000000000000000000000000000000000000000000000000
0000000000070000000700009030b3b000c00c0000c00c0000822800008228000a4444a00a4444a0000000000000000000000000000000000000000000000000
00700700007570000075700083b33b300d0110d00001100000222200002222000444444004444440000000000000000000000000000000000000000000000000
000770000077700000777000e03033300ddf1dd0dddf1ddd0e2f22e0002f2200004f4400004f44000dd0002c2000dd000000002c200000000000000000000000
000770008057508080575080e0203b300dd11dd0ddd11ddd0ee22ee0eee22eee09044090000440000ddd0c222c0ddd0000dd0c222c0dd0000000000000000000
00700700755755707557557002e233300d0110d0dd0110dd0ee22ee0eee22eee09944990999449990d1dd22f22dd1d00ddddd22f22ddddd00000000000000000
0000000077797770777877700282000000000000000000000ee22ee0eee22eee09944990999449990dd1d2f2f2d1dd00dd11d2f2f2d11dd00000000000000000
0000000070080070700000700020000000000000000000000ee22ee00ee22ee0090440909904409900ddd22222ddd0000dddd22222dddd000000000000000000
000000000700000000000000000000000000003300003000000000000000000000000000000000000000dd222dd00000000ddd222ddd00000000000000000000
0000000085800000000000000000000033333333333333000000000000000000000000000000000000000d222d00000000000d222d0000000000000000000000
000000007770000000000000000000003bbbbb333bbbb30000000000000000000000000000000000000dddd2dddd0000000dddd2dddd00000000000000000000
0000000079700000000000000000000033bb3bb03b3bbb300000000000000000000000000000000000dd1dd2dd1dd00000dd1dd2dd1dd0000000000000000000
0000000000000000000000000000000003bbb3303bbb3b30000000000000000000000000000000000dd1dd020dd1dd0000dd1d020d1dd0000000000000000000
000000000000000000000000000000003b3bb33033b3bb300000000000000000000000000000000000ddd00000ddd000000ddd000ddd00000000000000000000
000000000000000000000000000000003333330303333b3000000000000000000000000000000000000d0000000d0000000ddd000ddd00000000000000000000
0000000000000000000000000000000000333300030033300000000000000000000000000000000000000000000000000000d00000d000000000000000000000
00000000000000000000000000000000000000b00030000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000003b300b33b33300000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000b33003b33bb300300000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000003b3303000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000003300330033330b000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000003b303b3003b3003300000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000033b003b0033003bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000b30003000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000003000300300000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000030000030033000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000030003000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000003000300000003300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00111111100000100000000100001111110000002222222222222202222222220222222222220222222222220000000000000000000000000000000000000000
01ddddddd10001d10000001d1011dddddd1000002eeeeeeeeeeee202eeeeeee202eeeeeeeee202eeeeeeeee20000000000000000000000000000000000000000
01dd1111dd1001d10000001d11ddd1111dd100002e2222222222e202e22222e202e22222222202e2222222220000000000000000000000000000000000000000
01d100001dd101dd1000001d11dd100001d100002e2000000002e202e20002e202e20000000002e2000000000000000000000000000000000000000000000000
01d1000001d1001d1000001d11d10000001000002e2000000002e202e20002e202e20000000002e2000000000000000000000000000000000000000000000000
01dd10001dd1001d1000001d11d10000000000002e2000000002e202e20002e202e20000000002e2000000000000000000000000000000000000000000000000
001d1001dd10001d1000001d11d10000000000002e2002222222e202e20002e202e20000000002e2000000000000000000000000000000000000000000000000
001dd11dd111101dd100001d11d10000000000002e2002eeeeeee202e20002e202e22222222202e2222222220000000000000000000000000000000000000000
001dddddddddd101d100001d11dd1000111100002e2002222222e202e20002e202eeeeeeeee202eeeeeeeee20000000000000000000000000000000000000000
001ddd11111ddd11d10001dd101d1001dddd10002e2000000002e202e20002e20222222222e20222222222e20000000000000000000000000000000000000000
001dd1000001dd11d10001d1001d1000111d10002e2000000002e202e20002e20000000002e20000000002e20000000000000000000000000000000000000000
001dd1000001dd11dd101dd1001d1000001d10002e2000000002e202e20002e20000000002e20000000002e20000000000000000000000000000000000000000
0001d100001ddd101d101d10001dd10001dd10002e2000000002e202e20002e20000000002e20000000002e20000000000000000000000000000000000000000
0001dd1111ddd1001dd1dd100001d1111dd100002e2222222222e202e22222e20222222222e20222222222e20000000000000000000000000000000000000000
0001dddddddd110001ddd1000001dddddd1100002eeeeeeeeeeee202eeeeeee202eeeeeeeee202eeeeeeeee20000000000000000000000000000000000000000
00011111111100000011100000001111111000002222222222222202222222220222222222220222222222220000000000000000000000000000000000000000
00333333300000300000000300003333330000002222222222222202222222220222222222220222222222220000000000000000000000000000000000000000
03bbbbbbb30003b30000003b3033bbbbbb3000002888888888888202888888820288888888820288888888820000000000000000000000000000000000000000
03bb3333bb3003b30000003b33bbb3333bb300002822222222228202822222820282222222220282222222220000000000000000000000000000000000000000
03b300003bb303bb3000003b33bb300003b300002820000000028202820002820282000000000282000000000000000000000000000000000000000000000000
03b3000003b3003b3000003b33b30000003000002820000000028202820002820282000000000282000000000000000000000000000000000000000000000000
03bb30003bb3003b3000003b33b30000000000002820000000028202820002820282000000000282000000000000000000000000000000000000000000000000
003b3003bb30003b3000003b33b30000000000002820022222228202820002820282000000000282000000000000000000000000000000000000000000000000
003bb33bb333303bb300003b33b30000000000002820028888888202820002820282222222220282222222220000000000000000000000000000000000000000
003bbbbbbbbbb303b300003b33bb3000333300002820022222228202820002820288888888820288888888820000000000000000000000000000000000000000
003bbb33333bbb33b30003bb303b3003bbbb30002820000000028202820002820222222222820222222222820000000000000000000000000000000000000000
003bb3000003bb33b30003b3003b3000333b30002820000000028202820002820000000002820000000002820000000000000000000000000000000000000000
003bb3000003bb33bb303bb3003b3000003b30002820000000028202820002820000000002820000000002820000000000000000000000000000000000000000
0003b300003bbb303b303b30003bb30003bb30002820000000028202820002820000000002820000000002820000000000000000000000000000000000000000
0003bb3333bbb3003bb3bb300003b3333bb300002822222222228202822222820222222222820222222222820000000000000000000000000000000000000000
0003bbbbbbbb330003bbb3000003bbbbbb3300002888888888888202888888820288888888820288888888820000000000000000000000000000000000000000
00033333333300000033300000003333333000002222222222222202222222220222222222220222222222220000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000000000300000000000003000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00300003000000300000000000030000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000300000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000030000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030300300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000003000000000300000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00003000000003000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000000000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000003000000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000300030000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000e110151201b120261202f120361201f1203f1203f120331202a1202312019120171101b11027110351102a12017130111201b1201d110251102811031110351101d1102111025110000000000000000
0001000017650276502f6503265034650386503065037650306502f650316502c6502f6503365029650266502d650236501a650106500d6500c6500b6500a6500665005650056500565005650036500165001650
00010000197102671029710317202c720247202072019720137100e71005710027100170004700047000470003700000000000000000000000000000000000000000000000000000000000000000000000000000
000200000411007110081100911009110081100611004110021100211001110011101a1000c1000b1000710002100011000110000000000000000000000000000000000000000000000000000000000000000000
0002000001610026100261003610056200b620166201c620206200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000001520065300c540125400b530035300453003520025100251002510025100351002510015100151001510000000000000000000000000000000000000000000000000000000000000000000000000000
000100001b6201b620196201a6201862015620126200e6200c6200762006620066100661000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000071500a15215151231512a1512d1502e5522e5512e550325503f5513f550325502f5511a1501f150271523115031150291501a15016150101500e1500e150161503015033150371503c1503f1503a150
000200003d1503d1503f1503f1503f1503b15036150341503215032150311502e1502a150231501d150191501315013150121501215012150111501115010650166501c650276502f650236501a6501d6501f650
00010000281303112024120151200b110171102b12031130271201a1100b110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
012000080c0630c6250c6050c0630c0630c605187330c0050e1051020511305243052430524300242002410024505185053050518505187051870300000000000000000000000000000000000000000000000000
0120002005750047500475104751021000575007750077510775100100077500575005751077500475004700047500475102704057500475004751047510000005750077500775107751000000a7500775007751
01200000117500e7500e7500e75010750117501375018750167501075011750137500e7500e7500e7501075000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001c750107501d750117501d7501f7501f7501f7501f7500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000210561e0561b0561c0561c0510d0500d0510d0510d0510d0510c0500c0510c0510c0510c0510c0510c051000000000000000000000000000000000000000000000000000000000000000000000000000
013100000205028051190560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 0a424344
03 0a0b4c44

