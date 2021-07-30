local mod	= DBM:NewMod("Sindragosa", "DBM-Icecrown", 4)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 4438 $"):sub(12, -3))
mod:SetCreatureID(36853)
mod:RegisterCombat("combat")
mod:SetMinSyncRevision(3712)
mod:SetUsedIcons(3, 4, 5, 6, 7, 8)

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_AURA_REMOVED",
	"SPELL_CAST_SUCCESS",
	"UNIT_HEALTH boss1",
	"CHAT_MSG_MONSTER_YELL"
)

local warnAirphase				= mod:NewAnnounce("WarnAirphase", 2, 43810)
local warnGroundphaseSoon		= mod:NewAnnounce("WarnGroundphaseSoon", 2, 43810)
local warnPhase2soon			= mod:NewAnnounce("WarnPhase2soon", 1)
local warnPhase2				= mod:NewPhaseAnnounce(2, 2)
local warnInstability			= mod:NewCountAnnounce(69766, 2, nil)
local warnChilledtotheBone		= mod:NewCountAnnounce(70106, 2, nil)
local warnMysticBuffet			= mod:NewCountAnnounce(70128, 2, nil)
local warnFrostBeacon			= mod:NewTargetAnnounce(70126, 4)
local warnBlisteringCold		= mod:NewSpellAnnounce(70123, 3)
local warnFrostBreath			= mod:NewSpellAnnounce(71056, 2, nil, true)
local warnUnchainedMagic		= mod:NewTargetAnnounce(69762, 2, nil, true, 2)

local specWarnUnchainedMagic	= mod:NewSpecialWarningYou(69762, nil, nil, nil, 1, 2)
local specWarnFrostBeacon		= mod:NewSpecialWarningMoveAway(70126, nil, nil, nil, 3, 2)
local specWarnInstability		= mod:NewSpecialWarningStack(69766, nil, 4, nil, nil, 1, 6)
local specWarnChilledtotheBone	= mod:NewSpecialWarningStack(70106, nil, 4, nil, nil, 1, 6)
local specWarnMysticBuffet		= mod:NewSpecialWarningStack(70128, false, 5, nil, nil, 1, 6)
local specWarnBlisteringCold	= mod:NewSpecialWarningRun(70123, nil, nil, nil, 4, 2)

local timerNextAirphase			= mod:NewTimer(120, "TimerNextAirphase", 43810, nil, nil, 6)
local timerNextGroundphase		= mod:NewTimer(42.5, "TimerNextGroundphase", 43810, nil, nil, 6)
local timerNextFrostBreath		= mod:NewNextTimer(22, 71056, nil, true, nil, 5, nil, DBM_CORE_TANK_ICON)
local timerNextBlisteringCold	= mod:NewCDTimer(67, 70123, nil, nil, nil, 2, nil, DBM_CORE_DEADLY_ICON, nil, 3)
local timerNextBeacon			= mod:NewNextCountTimer(16, 70126, nil, nil, nil, 3, nil, DBM_CORE_DEADLY_ICON)
local yellBeacon				= mod:NewShortFadesYell(70126)

local timerBlisteringCold		= mod:NewCastTimer(6, 70123, nil, nil, nil, 2)
local timerUnchainedMagic		= mod:NewCDTimer(30, 69762, nil, nil, nil, 3)
local timerInstability			= mod:NewBuffFadesTimer(5, 69766, nil, nil, nil, 5)
local timerChilledtotheBone		= mod:NewBuffFadesTimer(8, 70106, nil, nil, nil, 5)
local timerMysticBuffet			= mod:NewBuffFadesTimer(8, 70128, nil, nil, nil, 5)
local timerNextMysticBuffet		= mod:NewNextTimer(6, 70128, nil, nil, nil, 2)
local timerMysticAchieve		= mod:NewAchievementTimer(30, 4620, "AchievementMystic")

local berserkTimer				= mod:NewBerserkTimer(600)

local soundBlisteringCold 		= mod:NewSound(70123)
local soundFrostBeacon			= mod:NewSound(70126)

mod:AddBoolOption("SetIconOnFrostBeacon", true)
mod:AddBoolOption("SetIconOnUnchainedMagic", true)
mod:AddBoolOption("ClearIconsOnAirphase", true)
mod:AddBoolOption("AnnounceFrostBeaconIcons", false)
mod:AddBoolOption("AchievementCheck", false, "announce")
mod:AddBoolOption("RangeFrame")

local beaconTargets		= {}
local beaconIconTargets	= {}
local unchainedTargets	= {}
local p2_beacon_num = 1
local warned_P2 = false
local warnedfailed = false
local unchainedIcons = 7
local activeBeacons	= false

do
	local function sort_by_group(v1, v2)
		return DBM:GetRaidSubgroup(UnitName(v1)) < DBM:GetRaidSubgroup(UnitName(v2))
	end
	function mod:SetBeaconIcons()
		if DBM:GetRaidRank() > 0 then
			table.sort(beaconIconTargets, sort_by_group)
			local beaconIcons = 8
			for i, v in ipairs(beaconIconTargets) do
				if self.Options.AnnounceFrostBeaconIcons then
					SendChatMessage(L.BeaconIconSet:format(beaconIcons, UnitName(v)), "RAID")
				end
				self:SetIcon(UnitName(v), beaconIcons, 15)
				beaconIcons = beaconIcons - 1
			end
			table.wipe(beaconIconTargets)
		end
	end
end

local function warnBeaconTargets()
	warnFrostBeacon:Show(table.concat(beaconTargets, "<, >"))
	table.wipe(beaconTargets)
end

local function warnUnchainedTargets()
	warnUnchainedMagic:Show(table.concat(unchainedTargets, "<, >"))
	timerUnchainedMagic:Start()
	table.wipe(unchainedTargets)
	unchainedIcons = 7
end

function mod:OnCombatStart(delay)
	p2_beacon_num = 1
	berserkTimer:Start(-delay)
	timerNextAirphase:Start(50-delay)
	timerNextBlisteringCold:Start(33-delay)
	warned_P2 = false
	warnedfailed = false
	table.wipe(beaconTargets)
	table.wipe(beaconIconTargets)
	table.wipe(unchainedTargets)
	unchainedIcons = 7
	self:SetStage(1)
	activeBeacons = false
	if self.Options.RangeFrame and (mod:IsDifficulty("heroic10") or mod:IsDifficulty("heroic25")) then
		DBM.RangeCheck:Show(20) -- Edit to fix auto showing range check with heroic mode values
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(69649, 71056, 71057, 71058) or args:IsSpellID(73061, 73062, 73063, 73064) then--Frost Breath
		warnFrostBreath:Show()
		timerNextFrostBreath:Start()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(70126) then
		beaconTargets[#beaconTargets + 1] = args.destName
		if args:IsPlayer() then
			specWarnFrostBeacon:Show()
			soundFrostBeacon:Play("Interface\\AddOns\\DBM-Core\\sounds\\beware.ogg")
		end
		if self.vb.phase == 1 and self.Options.SetIconOnFrostBeacon then
			table.insert(beaconIconTargets, DBM:GetRaidUnitId(args.destName))
			if (mod:IsDifficulty("normal25") and #beaconIconTargets >= 5) or (mod:IsDifficulty("heroic25") and #beaconIconTargets >= 6) or ((mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10")) and #beaconIconTargets >= 2) then
				self:SetBeaconIcons()--Sort and fire as early as possible once we have all targets.
			end
		end
		if self.vb.phase == 2 then--Phase 2 there is only one icon/beacon, don't use sorting method if we don't have to.
			p2_beacon_num = p2_beacon_num + 1
			timerNextBeacon:Start(16, p2_beacon_num)
			if self.Options.SetIconOnFrostBeacon then
				self:SetIcon(args.destName, 8, 10)
				if self.Options.AnnounceFrostBeaconIcons then
					SendChatMessage(L.BeaconIconSet:format(8, args.destName), "RAID")
				end
			end
			if args:IsPlayer() then
				yellBeacon:Countdown(70126, 5)
			end
		end
		self:Unschedule(warnBeaconTargets)
		if self.vb.phase == 2 or (mod:IsDifficulty("normal25") and #beaconTargets >= 5) or (mod:IsDifficulty("heroic25") and #beaconTargets >= 6) or ((mod:IsDifficulty("normal10") or mod:IsDifficulty("heroic10")) and #beaconTargets >= 2) then
			warnBeaconTargets()
		else
			self:Schedule(0.3, warnBeaconTargets)
		end
	elseif args:IsSpellID(69762) then
		unchainedTargets[#unchainedTargets + 1] = args.destName
		if args:IsPlayer() then
			specWarnUnchainedMagic:Show()
		end
		if self.Options.SetIconOnUnchainedMagic then
			self:SetIcon(args.destName, unchainedIcons)
			unchainedIcons = unchainedIcons - 1
		end
		self:Unschedule(warnUnchainedTargets)
		if #unchainedTargets >= 6 then
			warnUnchainedTargets()
		else
			self:Schedule(0.3, warnUnchainedTargets)
		end
	elseif args:IsSpellID(70106) then	--Chilled to the bone (melee)
		if args:IsPlayer() then
			warnChilledtotheBone:Show(args.amount or 1)
			timerChilledtotheBone:Start()
			if (args.amount or 1) >= 5 then
				specWarnChilledtotheBone:Show(args.amount)
			end
		end
	elseif args:IsSpellID(69766) then	--Instability (casters)
		if args:IsPlayer() then
			warnInstability:Show(args.amount or 1)
			timerInstability:Start()
			if (args.amount or 1) >= 5 then
				specWarnInstability:Show(args.amount)
			end
		end
	elseif args:IsSpellID(70127, 72528, 72529, 72530) then	--Mystic Buffet (phase 3 - everyone)
		if args:IsPlayer() then
			warnMysticBuffet:Show(args.amount or 1)
			timerMysticBuffet:Start()
			timerNextMysticBuffet:Start()
			if (args.amount or 1) >= 5 then
				specWarnMysticBuffet:Show(args.amount)
			end
			if (args.amount or 1) < 2 then
				timerMysticAchieve:Start()
			end
		end
		if args:IsDestTypePlayer() then
			if self.Options.AchievementCheck and DBM:GetRaidRank() > 0 and not warnedfailed then
				if (args.amount or 1) == 5 then
					SendChatMessage(L.AchievementWarning:format(args.destName), "RAID")
				elseif (args.amount or 1) > 5 then
					SendChatMessage(L.AchievementFailed:format(args.destName, (args.amount or 1)), "RAID_WARNING")
					warnedfailed = true
				end
			end
		end
	end
end

mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(70117) then--Icy Grip Cast, not blistering cold, but adds an extra 1sec to the warning
		warnBlisteringCold:Show()
		specWarnBlisteringCold:Show()
		timerBlisteringCold:Start()
		timerNextBlisteringCold:Start()
		soundBlisteringCold:Play()
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpellID(69762) then
		if self.Options.SetIconOnUnchainedMagic and not activeBeacons then
			self:SetIcon(args.destName, 0)
		end
	elseif args:IsSpellID(70126) then
		activeBeacons = false
	elseif args:IsSpellID(70106) then	--Chilled to the bone (melee)
		if args:IsPlayer() then
			timerChilledtotheBone:Cancel()
		end
	elseif args:IsSpellID(69766) then	--Instability (casters)
		if args:IsPlayer() then
			timerInstability:Cancel()
		end
	elseif args:IsSpellID(70127, 72528, 72529, 72530) then
		if args:IsPlayer() then
			timerMysticAchieve:Cancel()
			timerMysticBuffet:Cancel()
		end
	end
end

function mod:UNIT_HEALTH(uId)
	if not warned_P2 and self:GetUnitCreatureId(uId) == 36853 and UnitHealth(uId) / UnitHealthMax(uId) <= 0.38 then
		warned_P2 = true
		warnPhase2soon:Show()
	end
end

function mod:CHAT_MSG_MONSTER_YELL(msg)
	if (msg == L.YellAirphase or msg:find(L.YellAirphase)) or (msg == L.YellAirphaseDem or msg:find(L.YellAirphaseDem)) then
		if self.Options.ClearIconsOnAirphase then
			self:ClearIcons()
		end
		warnAirphase:Show()
		timerNextFrostBreath:Cancel()
		timerUnchainedMagic:Start(56)
		timerNextBlisteringCold:Start(78.5)--Not exact anywhere from 80-110seconds after airphase begin
		timerNextAirphase:Start()
		timerNextGroundphase:Start()
		warnGroundphaseSoon:Schedule(37.5)
		activeBeacons = true
	elseif (msg == L.YellPhase2 or msg:find(L.YellPhase2)) or (msg == L.YellPhase2Dem or msg:find(L.YellPhase2Dem)) then
		self:SetStage(2)
		warnPhase2:Show()
		p2_beacon_num = 1
		timerNextBeacon:Start(7, p2_beacon_num)
		timerNextAirphase:Cancel()
		timerNextGroundphase:Cancel()
		warnGroundphaseSoon:Cancel()
		timerNextBlisteringCold:Start(35)
	end
end
