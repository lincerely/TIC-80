-- title:  Benchmark
-- author: MonstersGoBoom
-- desc:   several performance tests
-- script: lua

local runningTime = 0
local t = 0
local RUNNER = {}
-- predictable random 
-- give the same sequence every time
local random = {}
random.max = 8000
random.count = 0
for x=0,random.max do 
  random[x+1] = math.random(100)/100
end
function Random(v)
  random.count = random.count+1
  return random[(random.count%random.max)+1] * v 
end

-- epilepsy warning
local Warning = [[
A very small percentage of individuals
may experience epileptic seizures
or blackouts when exposed to
certain light patterns or flashing lights.

Exposure to certain patterns or backgrounds
on a television screen or when playing
video games may trigger epileptic seizures
or blackouts in these individuals.

These conditions may trigger previously
undetected epileptic symptoms or seizures
in persons who have no history of prior seizures
or epilepsy.

If you, or anyone in your family has an
epileptic condition or has had
seizures of any kind,
consult your physician before playing.
]]

-- UI stuff
local UI = {currentOption=1}
-- default UI for each test
function UI:bench()
  print("Press Z",170,130,15)
  -- back to menu
  if btnp(4) then
    RUNNER = nil
  end
end
-- main UI
function UI:mainmenu()
	cls(1)
		print("Let the test run until the bar is full",0,0,15)
	
	--	print position 
	local yp = 68-((#UI.options*8)/2)
	--	what is selected
	local currentOption = 1+(UI.currentOption % (#UI.options))
	--	display options
	for o=1,#UI.options do 
 	color = 6
  opt = UI.options[o]
  if o==currentOption then 
				color = 15
				-- if highlighted and press Z
				--	then start it
				-- and set to white
				if btnp(4) then
		  	RUNNER = opt[2]
		  	-- if we have an INIT then run it
		  	random.count = 0
		  	if RUNNER.init ~= nil then 
		   	RUNNER:init()
		  	end
		  	RUNNER.count = 0
    end
  end
		--  display text and results
		if opt[2]~=nil then
			if opt[2].count==nil then opt[2].count=0 end
			s = opt[1] .. ":" .. (opt[2].count * opt[2].callmult)
		else
			s = opt[1]
		end
		print(s,xp,yp,color)
		yp=yp+6
 end
	if btnp(0) then UI.currentOption=UI.currentOption-1 end
	if btnp(1) then UI.currentOption=UI.currentOption+1 end
end

-- SQRT test

local SQRT = { add = 1 , callmult = 2}
function SQRT:init()
end
function SQRT:run()
  cls(0)
	local wiggle= t/20 % 20
  for y=0,136 do 
    for x=0,RUNNER.count do 
      pix(x%240,y,16-(math.sqrt(wiggle+(x*x + y*y)/136)%16))
    end
  end
end

-- SINCOS test
local SINCOS = { add = 1 , callmult = 5}
function SINCOS:init()
end
function SINCOS:run()
  cls(0)
	local wiggle= t/20 % 20
  for y=0,136 do 
    for x=0,RUNNER.count do 
      local v = 0
      v = v + math.sin(wiggle+x) + math.cos(wiggle+y)
      v = v + math.cos(wiggle-y) + math.sin(wiggle-x)
      pix(x%240,y,v%16)
    end
  end
end

-- READ WRITE TEST

local PIXELRW = { add = 1 , callmult = 1}
function PIXELRW:init()
  print(Warning,0,0,15)
end
function PIXELRW:run()
	local wiggle= t/20 % 120
  for y=0,136 do 
    for x=0,RUNNER.count do 
      local a = pix(x+wiggle,y)
      local b = Random(100)
      if b<25 then
        pix(x,y,a)
      else
        circb(x,y,4,a+1)
      end
    end
	end
end

-- WRITE TEST
local PIXELW = { add = 5 , callmult = 1}
function PIXELW:init()
end
function PIXELW:run()
  for y=0,136 do 
    for x=0,RUNNER.count do 
      pix(x&0xff,y,32+(x+(y*8)))
    end
	end
end

-- math.random
local MATHRANDOM = { add = 1000 , callmult = 2}
function MATHRANDOM:run()
  cls(0)
  for rc=0,RUNNER.count do 
    pix(math.random(240),math.random(136),math.random(15))
	end
end

-- circles
local SHAPES = { add = 25, callmult = 1}
function SHAPES:run()
  cls(2)
  for x=0,RUNNER.count do 
    circ(Random(240),Random(136),Random(16),x&1)
  end
end

-- map 

local MAP = { add = 1 , callmult = 1}
function MAP:run()
  cls(10)
  for x=0,RUNNER.count do 
    map(0,0,30,18,-x,0,10)
  end
end

-- sprites

local Sprites = { add = 100 , callmult = 1}
function Sprites:run()
  local a = t + 1/RUNNER.count
  cls(0)
  for x=0,RUNNER.count do 
    spr(1,120+math.sin(x+a)*120,68+math.cos(x-a)*68)
  end
end

-- falling dots
local Particles = { add = 0 , callmult = 1}
function Particles:init()
  Particles.list = {}
end

function Particles:run()
  cls(0)
  table.sort(Particles, function(a,b) return a.y>b.y end)

  if (t//40)&1==0 then
    if runningTime<16.2 then 
      for x=1,100 do
        table.insert(Particles.list,{x=Random(240),y=-Random(32),c=1+((x//10)%14),fs=0.5+Random(5)/10.0})
      end
    end
  end

		Particles.count = #Particles.list
 
  for x=1,#Particles.list do 
    p = Particles.list[x]
    if p.y<100 then
      if (pix(p.x,(p.y+p.fs)//1)==0) then 
        p.y=p.y+p.fs
      else
        if Random(100)>80 then
          if (pix(p.x-1,p.y+1)==0) then 
            p.x = p.x-1
          elseif (pix(p.x+1,p.y+1)==0) then 
            p.x = p.x+1
          end
        end
      end
    end
  pix(p.x,p.y,p.c)
  end
end

-- options

UI.options = {
  {"Shapes",SHAPES},
  {"MAP",MAP},
  {"Sprites",Sprites},
  {"Particles",Particles},
  {"Write Screen",PIXELW},
  {"Read and Write Screen",PIXELRW},
  {"Math.Random",MATHRANDOM},
  {"Math.SquareRoot",SQRT},
  {"Math.SinCos",SINCOS},
--  {"Packer",test_shapes},
}

RUNNER = nil

function MAINTIC()
  local stime = time()
  if RUNNER~=nil then 
    if RUNNER.count~=nil then
      if runningTime<16.6 then 
        RUNNER.count=RUNNER.count + RUNNER.add
      end
      if runningTime>18.0 then 
        RUNNER.count=RUNNER.count - RUNNER.add
      end
      print(RUNNER.count,0,110,15)
    end
    if RUNNER.run~=nil then
      RUNNER.run()
      runningTime = time() - stime
						rect(0,119,240,6,0)
      rect(0,120,runningTime*14.20,4,15)
						
      print(string.format("runTime %.2f",runningTime),1,127,0)
      print(string.format("runTime %.2f",runningTime),0,126,15)
      if runningTime>16 then 
        UI:bench()
      end
    end
  else
    UI:mainmenu()
  end

  t=t+1
end

t=0
function TIC()
  cls(0)
  local y = 136-(t/3)
  if y<0 then y=0 end
  print(Warning,0,y,15)
  t=t+1
  if (t>60*2) then
    UI:bench()
    if btnp(4) then 
      TIC=MAINTIC
    end
	end
end


-- <TILES>
-- 000:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 001:0333333033777733377aa77337affa7337affa73377aa7733377773303333330
-- 002:fffffeee2222ffee88880fee22280feefff80fff0ff80f0f0ff80f0f0ff80f0f
-- 003:efffffffff222222f8888888f8222222f8fffffff8fffffff8ff0ffff8ff0fff
-- 004:fffffeee2222ffee88880fee22280feefff80ffffff80f0f0ff80f0f0ff80f0f
-- 005:efffffffff222222f8888888f8222222f8fffffff8ff0ffff8ff0ffff8ff0fff
-- 006:fffffeee2222ffee88880fee22280feefff80fff0ff80f0f0ff80f0f0ff80f0f
-- 007:efffffffff222222f8888888f8222222f8fffffff8ff0ffff8ff0ffff8ff0fff
-- 008:fffffeee2222ffee88880fee22280feefff80fff0ff80f0f0ff80f0f0ff80f0f
-- 009:efffffffff222222f8888888f8222222f8fffffff8ff0ffff8ff0ffff8ff0fff
-- 010:fffffeee2222ffee88880fee22280feefff80fff0ff80f0f0ff80f0f0ff80f0f
-- 016:2222222222222222222222222222222222222222222222222222222222222222
-- 017:f8fffffff8888888f888f888f8888ffff8888888f2222222ff000fffefffffef
-- 018:fff800ff88880ffef8880fee88880fee88880fee2222ffee000ffeeeffffeeee
-- 019:f8fffffff8888888f888f888f8888ffff8888888f2222222ff000fffefffffef
-- 020:fff800ff88880ffef8880fee88880fee88880fee2222ffee000ffeeeffffeeee
-- 021:f8fffffff8888888f888f888f8888ffff8888888f2222222ff000fffefffffef
-- 022:fff800ff88880ffef8880fee88880fee88880fee2222ffee000ffeeeffffeeee
-- 023:f8fffffff8888888f888f888f8888ffff8888888f2222222ff000fffefffffef
-- 024:fff800ff88880ffef8880fee88880fee88880fee2222ffee000ffeeeffffeeee
-- 025:f8fffffff8888888f888f888f8888ffff8888888f2222222ff000fffefffffef
-- 026:fff800ff88880ffef8880fee88880fee88880fee2222ffee000ffeeeffffeeee
-- 032:0f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f00f0f0f0ff0f0f0f0
-- </TILES>

-- <MAP>
-- 000:010101010101010101010101010101010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:010101010101010101010101010101010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:010101010101010101010101010101010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:010100000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:010100000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:010100000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:010100010101000000000000000001010100000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:010100010101000000000000000001010100000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:010100000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:010100000000000000000000000000000000000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:010100000000000000000000000000000000000000000000000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:010101010101010101000000000001010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:010000000000000000000000000000000000000000000000000001010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:010000000000000000000000000000000000000000000000000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:010100000000000000000000000000000000000000000000000000010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:010100000000010101010100000000000000000000010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:010101010101010101010101010101010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <PALETTE>
-- 000:140c1c44243430346d4e4a4e854c30346524d04648757161597dced27d2c8595a16daa2cd2aa996dc2cadad45edeeed6
-- </PALETTE>

-- <COVER>
-- 000:6db100007494648393160f00880077000012ffb0e45445353414055423e2033010000000129f40402000ff00c2000000000f0088007841c0c158591a58c403435642571716444243e4a4e40343d695d7ec0d6484d6aac22dd7c2edee6d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080ff001080c1840b0a1c388031a2c58c0b1a3c780132a4c9841b2a5cb88133a6cd8c1b3a7cf80234a8c1942b4a9c398235aac59c2b5abc790336acc9943b6adcb98337aecd9c3b7afcf90438a0d1a44b8a1d3a8439a2d5ac4b9a3d7a053aa4d0a106aa5dba853ba656a5532a006a306ba85d8406ce7c20663daad78867dabd7be5316bda8604ce108b873f2f440a7146200aa0afa2c2bf1718d4eb0020b0669167cedd5c11bea064c9090bc49c32d234edc40d037efc019238ed9e9b5675d8f75a63e1dca3169e18a9543943cf834f1c9bb7b5b8c5d911335cfaab372e668fa38384ed5018b1f5ecc3f6de6e4135b3c9b2d14e0f195cb466fa9acd52283d251cf1ff4dcc09c3749da2f934cee595ea444fa0fe2c70090c7be41f527ebdf095d33f1cdf9cd246e5743f11430e048c1948f1d400a44ce154bd1145d1f690e44706740c5383e54411614d124700c78b1d28e319830d577b1745657751a34bd5b8045386261403e4723dc891d38205a6a1624571f5df9e8d3946ae547c051083a88c0518115d80041961149405b5df9046084931559000a8000a783214104d5a5ee8b0d7906a14c5a7466a048521720a54a4a345b500256f8605c96090950da912e1436a04cedf9e0d5801968a4a0aa1916e4e247047554e37c4af9801f9d61e9eedb980510d0249d663422e7596ea48864af758a67e1416699b0536b048ab7224eb1dff98054a309f689949d961450696c7e292966a21a1448a34c7a5a70900532a52b169d222ab1dd590677a76f9229bad055768577ebd89dba84d3a3bfa6c5b2126b0e0824227502a55bd10fc116c5e28b821950df5891da00c0b80800a9557a5658100879a9eb3190c30dd56de3bf01f8004d5ba57710007f120703685a8dd9d8a780b144cb9095465740cc883256485f79ded980d2afba04ea6004b2695a5eb0088780010491f570a104aa395b9db93a442d9002bd002d5b9d51a83c23482b34a5ac629d4b5b6cce32fc8090024207f51665083d119baa5fdb7222d7da5950b1470c0b9d57d50989811ad057bd80a4768e14e4a56f71cc20536a957a70e1d2059ff66046716d5cabe2c35634bf1e7247cda0520ce6add61a594f14fa1f9bad18f16481de9a4f1d6796e9c1d10c93a44080068df5555105a926f7d363c5ed00ca6579d72959ee5399b8b1416d207a528d6e20dd1e655e07dd6004379c6022468968a9f04acd2ff4aae70dd5887fdfa76cbaf2c2fe3d4d779adb042b517c8bfe00827c73f58fd206c675900263f9005d94d401b70f3bdcdb04c7b162b2289054e6873d383142f9d2924c033ab8d910c2340820c00800700e29bec02dd2fed4e4a37a1d11dfa06c424b08b8645012c49688680233d79cc3e43a75798560b200a3b423108aecf8cd44da6f4764009ba1884729746bd15b8aa23085dc202c20f900c00ffa005347b10a236c14c1d3c6c71caeccb6ee2b1caac384432006897fea3b4cb71f5437e99c51c7494779651d742251afa800ab2f03dd9140e6600bf0a88175510f8a7ab24990b4006e27a20ec0dcb73f2e0ef9e06c24bd114c00d59ab897217fd110231519e03b1614683f5990924e06b09ef0cd2b6f5b546640946ca721dc8f648c688a7896f846311ea0751ceb5788d7e63eb45c898ce92b0dc419301500f5e56ebaee0f5829f42bf419ce36abd2141512881f0610027b0020c58e93e4356d92f570e93d01f077ad3bc400b33489b027f800600efd1f2f4e99ea4368653029911401080830cb29170044e9480c32429d4a370328cd2d2a4d73828d85eef67ffe46edcae49f797dc1d443f81400ab6c8892d7aaca67d3a7dccec19ff135e988d3494a010b00670481120c73b040fcb6e89a1cae8e8299608a45140a453b40881d0275ad865fc880b111dc5eb3eeb30436aa2d6c300f52c22bb886dae145699b8bf8f825203249c33f4ce7ed5e86300fc02b407fa9a3608e5ac624c04c49690548e9371063d386f9a543bcc4624e4370024216ea4a5de21a5915409cd9d3702da2e2da458529a606735b526d011bbe1375390df9cc8b22b6120418e9b01ee9a83c0c71ab3768400f123fa1b83bf1228a175a93bedd6b830112a8d4397c33005d423869aa4a6e00df9b059e08448310cc5604681cdcb25c82ad67e394f9d530fff5c01f70154e04a03658d58db170061c10197a1b4abe76cc6188084042e8f821d3e12680bd691a2c5366559c51fda337ec5fd2f4955aa62a340832e420467ac21b5bf97da003339c6df6c79a12c2d2fe683b31d01bd6d8d4e1753c5552b66d8a364720e49d47a83b45dbe6383f2b9a04ef5199e29794567a3cfc7c6db36d55976a7835a0aed1b003abe79977c88b17f9f0d87014615271ea0f9100a3947708a22d07798ed9d20b8aad7c1bd3646907524a6acd7385d9e0084bbeb136175d5cb97c001110a6ceed247c75dd480a3997f73aa5deac28c1d3af33685fc1889f083335ec9d78f4e9d975202b9401b5e68e4456dd1de4d77d0caf6955f5b2ee3d076ff9c5b326e199ac8e338ee859b4a520420086ecc9cefc8e410054520bcc844ae1ec41040318820a6334c400dbc0c03510a27f0c0825e43e8e4b0840489c096c5d863a610b6d9376693b7ac6c02980db524d6dea433ec46613f57d64a1230147446d9aa4577b7eaa4678d583bfb8664d67011d86abe3e865e6cafe8f56af41d6882a93069d095571aa1f51d74f11a5555358a5b3ad4b180a6576e9366cdce06b504725cad551318aad50aeb435da540d75e439c6b1efdabd19dbb918e16c8360e7563a83330c7973a4eee66952fdced596b15188b5af4a8ff50a3dd51043d8c256a0da1b2ed336f07fc4ad6022b0d24e3e16240a83b6743ecc0ad2c4130786af1ff3c0329ef5f9547afec00a0812a877bd3abe1275700f035629ee89aad2bdfb6109ec104c7d0ad8571b592d9f5e85b0d3c49fa6418e076444f7720888c8bc139639b9045c8769667742d1079877ccd190198cd64a953aae39e467d799b976cca9e47479edfec7918ba255deaf04795331b6a8879ecf7d59afb70cf162d147f954d1a3d3b2374f20dbbe99def0ecfe8916fcecc48862e336ba0ad34cca9ee07ef7bf79a45cb8be9999d57af3c2b66a9b92edd8e5eb8783f6ae64fbc4c3d4b3e48691774375fcd90cc53ec3d99c5caf64f895257f9deb7f77c41b87f2e9c6d43ece9d8ab0433018eee324ef0dd7c041227b510c0fa26b05f556bc8e103f5b36eaeff8eeceb0c46ae9b1595bcb7bd5dff5f47eccb5577405339856c5dfd3d053d8ed897511dcefea3f64fbe434200a00667fd1472484195b76247357400a008e36e7ab3b97162162cd4ab37741627643e3da5842626ec64f7ea78d7d34a04d64b045c6b77b046370478e7b04d856370974a3ef6b28bb7816da2f13d850a3e869c58a3ac4cd4186d040c7128d243577047753440a6f779f2525928c23837433fd1d45a357578e6243c18708ec7357d04fc59819726050f7d82800a00bc7a37a76b38b768e57c4c28f73cd49260a3517996453d45b472e5a967289269e4b57eb34474538e3d45043635181484ad5ac5da2d45dd4d64333b156d72474a5df5d340974cff3c68c838860c58c2f289e4a04817be3b278e5484446c663572c73b62444c35c31b6433752e68b87dd7357605926997f34b57e86b778e5f94f37377926195d67368bd62a87748c3ff28a3567e08b04c37dd4f07b382445674a3f68f13635953147a96af68e4ea7626f56dd6af29960a6b96aa5fd16a8ee39c4183837ba84724474442373083085970a3f48ae69c4a25243385752588e165e84387c45f1128c04128a92776565626488f07043b76c550f7517dd4d45b981c7f280f7a928163687c4877c674b6162ce2c046383a3a04b47a00dc79c59668942c2af2f567c4137ef6525f481b7626472f079e4da2998ac58e4ac4fd1816357e97d854723a30478eff4377d57f03ac8433e86757554f589a7b57207e398c69353f6a29527e16117525718c585f7288218b486b4484f37b28dc7d24b36b96f34716444147eb3837109c185f1444c08f563578426a8a76e86ed8318333c83e379f8a92a354c3d45964af2f03f73b76df73675548b3d04378b08d473094469c43085657776977742776054270435b6f07b888b62089c58e38420c78e55632284c5f68ac56685659392474348169835c7aa57b7eb3453446953f39a35af2f738d6689d34a26c36aa7554ae6067b367f72473f68888e48e45651a9cd6067bd7518ef6ff27889f2d85d08568a00c83ac7525ce2b26c231958197047e7472a96186752f070d8c253850684fff7d04d828c2c29a292775d75987c4797ad54a3a68cd8b77074708d64996888eb3444367c18aa5308752f573487047f8be3826b76467e68043d08438837767a67ea6a357a60436670d9b68996fc6904c23f136099f2eb3537f77cd9cb7839108385fd1175d348a7f13a79218589ae98f7a767742d94a3d98cf66a9d258b99b72c7a25384908dd74f7047037ae8d498e5472c36ac5453be30e77c4333c48f2ada29c44a5836ff6996837b971e7f094a3e07a76d64a961474a54291f7186816ce2a04e89ef64f8453e774e6d820f96264a7833344037f34977ee8cd4cb76696765a7b77638247a37c55244208d85f97418f68434d382b61c9047228eb399647277ff61f73850d6635aa505775afc9287047062a359f2c19eb3ff2488186da2106309f6a309908db9a96ce2c8a538344243117ca8c284270e7d85ca83f98a30d9ab39689d95180f9519446385d24168f8846a448ab3ad7839ca8c29527e86d45f13554ff55f55a79c4639a99f945256d9b790a30689f2029dd4799186b768a96f9798635c2389624a8e5ac5c69cd6149b26e86f2a30a4548397792471571496b70a30585c6677bf8fd1704dc74440b9f07359e08f032a8446a8867671768abd73a956ad345b634a38525a6f9d64c77ad7a87f94ff6434ba7bc7d34dc8e95836ac4b997384190a7ffa7d837af295378b6cd4f39aca2d7ad9fc972854af287a6f37d0ff9e955655255f1d37b36429243a8756546891af9afa7634433626cd4f072f732acc67b8d45a96ea68b78260a6a19ea66379f26c674a067d46d15b15936537227be3d86538508c48f0a1297371e8457904709bf88a7e77ac49159c48c2d77ff5d89e86f137266f8c83af2b36a88f733d9605be3100a192e5e28ba9f56a78aa9b29f132434c3a59aa76687f8f0bb48a9905869982aab3a761475548692e5075c04fd12ab775726b36926d29ac48e54b7a9a3ea0b974a635f1bda2bd61d7f8b0a6569cb6f07d15344244b978a7ba8ef800972668b0a6c55b19a8abe3339043e778e3e792d6c098875f11895545294ea868428f0795347a0a6979ff7f139a8488f9ff500657817b9e6c075270252a801887b9e4aa51864348badca8c230a47acc84fa70648820929a0888e8ce2446638227d858994477fa247aa9807aab01828ba9266740bd3bc78976e29857d04f574197525f199618771cc0771cbf7848bbb7aaf038a3b04db6904775a257ebf45e167e7b00308aaa1295d810917abc90c58788c2df5186c6aa8a08a8e5d78f68a67186988816f374e6e3a50aa8808af876c68e4a925f19f3e168e32e8428b998e3aa52d6b5944674a842d378d7a38648dba417cca9bb47b4447ba5b65f1ac48e3985aa7b59433b868d9a194c30f7e8b98bc67d64968e293684533db7e9b29d0892c968a04f96377ad73dbe77718b08217f03b2ff8764ec7119577edbd39bdb938d824ea02a6889c40f7047caac0985972640b2179dbf96486a256356a8676525333208eebd6c7f8cda8a3f59bc94a31e3e2730885b0c9519966c2320972caf66d7cb783bee3299ff7563a4a904025eb324819ac27385b3b04c608b0acb6947ad98429cbf732d8d24787e6795ac379ac6590a6157797bd8308a26eda1623c66979c5aa5f0756a9c572cec6f138ea11bb3ad9a757f5ca27b4c9974572199c4479d452e7ee7b369ab0062fb41a9983387640b749c635eba6590c5fa9ea74b6344764368cc610b0c5d25b68563b0a17ae29886e479a738bcc65d88f9d34ef692b0c5779f979c559bccb900308018ea6ec6facdca7dff97575799e6a68953e16f7324784bc6b1e3ac4ee8a25d97077c48d86eeabe3c04dead247a7ce67a9b158d77f2e3cd79764a3b208de8247e27d5518ca7c9776090a7f8bd19a5950410ce974a54258483672aaa69cfa667c9a953df5cfac39f9c4a349767a40c6993675c7576738f581e32b99e7c764cad34c5cf95c7b32c9041daf1b1b61c76364a5626f8a2c9386b7671a043ec6b67b48c04a04368dfa05719d4fcd98e476e9f7379c50c333c3ca8acd85760c5689f9aa36c292a7dba2cc50cbaa816e98eba565472e1d5c6189ca98f6d9bec848b599243c833480065173863335636c6752ceaacb4b9d5991a49cdbacda3a86b48377c4b472079c9cb7418aeff6a767366b44195ba605b57d863d9b75c36c55bc70c9c3c836a92833739776446162243e6858810a9267f2983842257839e952e7e95e951b730e618c6b81a0a6b7a98b926fd89bd1470c54edb36669c837285bac5519adf60d7597817f487267880fdd34458a9901e8f7fe94352ab739b98ae8888ad5bb9d7b2abfc9752927d69087f57d596b69e58e68a900e4cbdf52bb19a4253dbd3b07d6c886c327539385fc75393a9cadc085610889f9f675a9139cd7c55e29fdafe8468a278e8576eda6650c53e74340060a60a7ff584b635b0ec9ab04c36f3bffc9ddcfc04ccd456710660826aa76c97c297b7d084440c8b18887257816fa7c7e81b5f77eae97e7ba7ff7d2da09218269c8c300a00137ae6e37dac31db8a9b7d04c23678b370299e6dd64a7cca25a983fdaf945acd0747c009efca1b0a70d8976acbcca4a5a048995c8086f07b8682dd4710961cc47a3de47a2541e7f857df34119904d48fa8764f67f0357aae46d7d576482889db61c3a368b01735a7c7c2c977d389c58c7ada05c06ea8afac8e3e47d07ce9e8910d2e5fac886433108964b960edb38da2079ef9fb8095bed248ce9724cc8719ab38aa739df7635c9ad4ce95378453c0cc1aa355bcf4538b27882dc788c88accda45c09d7aa0b71175d8479b977646054444e94fd777c83b9db36b4c94e82a0b703830ac6a588c237a6e7b49d71c2baac552db3bcbff65678e75c8a4d5c7cfa2ab76d5cbacac18b0a44bf34d08d0c7760d6c8aee345316a3fd9963385e9b8aba90fe4ad1f7ebb0fccb7109d0999dc695e85fdaf2a9e8765ac01eef8c79cca43c32d74985e0438b961738652ce48ad917e69dc23889e955ba6b49bb52d17a195c192fbbc8f983b8b96fc9b5a876d8824c56a49c14de7a4ca10845c5cdacd309dfb0d882a36e61c19a577fdab9685b27a3ea6884f85da1de767768117736a68983217be305cda9218da88a3a6759f47ab0889912fff208626eb67b7740b8d9e57c2c676c364d79bcceba4b0fd8665181a9f34aa7f277376c7ffe5f1e3b4a7b15a4dc67fb8cc68e3ef6aa5a9d05b29a2c7d0edebc2905ff8e47b29b57becc39ef6edb54807841748a09fc5a2e982603960b0fcd25147fbc82fccc28850a83a86fb4fdd4fa9eeb2c717fcc800190e0c105080c0c085040c0428404001018401001e20107001c10488041c101020a124440302087c10e0346101080408185070a0c04494020c145030222182960766084840a3e0030808760549e21141820339042d4052b081800e0b92f41090d0e1850c0b00ec3090e1e3cca5230c847954b5e1058b02aa1420d2d7628791045a183005f56283840a6e34b8a0db26c10d7500258bd6356b56980d0c064012700ac49c350244581276e6daab3b04244a64392a5998654e6e3aa00a2cd8a251d62c5080782b68a049e6467ff810c26be1092912bc40e671418101c50c004087d124d198731cac30217caf4c8a0d322869a6b326d1b57546ac79559223fda21bd26c505071a185cd55ea00e9fb98adc5c01d6734cb04714652001767b599b0e163daaa92b9a6a9961ae84923808a6ec0020abacd872b8e1b50c000e072ff41b1c09a19242fa2224f0044b8a3dfc5aed083794b34f6c2ffa04bda13792006a4629948ada0aafdc32582f379aa3d882c3a21a9968b1ae024b83acae1a60b3c601824a48aeaa13f9e926f2006840a6a29a208341982ccdca471bdabf2b210c0bb82bc8273ba86ca7ae0a0e63cbfea478e00006e4a3be4b3fe4c33f4d37f4e3bf4f3ff4043051470524b0534f05ff443155471564b1574f158432594725a4b25b4f25c4335d4735e4b35f4f35053451574525b4535f45453555575565b5575f558536595765a5b65b5f65c5375d5775e5b75f5f75063851678526b8536f85463955679566b9576f9586910967a5a6ba5b6fa5c63b5d67b5e6bb5f6fb5073c5177c527bc537fc5473d5577d567bd577fd5873e5977e5a7be5b7fe5c73f5d77f5f61a5f7ff50830e04910e3bad9390e189ec96dec58f069651e78d164810868d06a83263833e68f2648d2608b2e389369891e88f2ea37268892e4994e09fec9890ee81665855e09f56a976e69176d9b6ed9f6ef7b36a95665918e7898ec9f569939ed8176a694e2a78698366c87ae0a29796f9f6ed8b9ee9df549d868a3860b54ec91ae4a5f40a7ce99136687d6b9f46cab7e6b1fc8b30649546fafe67b7ce2b366799ae693beaa3074a5ae1c1ee395becadf4da315f87beebb4e5b9458c50604d660c1269a3fcab936eb32f0a9070bb2e9c9279c3dea971e0cdc6dc996fc16609ffe0d1d62d5454c3fe3c756bdd566df075bd67fa16f9db4dab78fcc5c6ed74739397fdd1ebddeecb73f0e3a78430200b3
-- </COVER>

