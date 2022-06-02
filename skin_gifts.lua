-- AUTOGENERATED CODE BY export_accountitems.lua

local SKIN_GIFT_TYPES =
{
	anchor_nautical = "TWITCH_DROP",
	arrowsign_post_circus = "TWITCH_DROP",
	beebox_crystal = "TWITCH_DROP",
	beefalohat_klaus = "TWITCH_DROP",
	beefalohat_pigking = "YOTP",
	birdcage_circus = "TWITCH_DROP",
	cane_ancient = "ANRARG",
	coldfirepit_teeth = "TWITCH_DROP",
	dragonflychest_kraken = "TWITCH_DROP",
	dragonflyfurnace_crystal = "TWITCH_DROP",
	emote_swoon = "CUPID",
	eyebrellahat_crystal = "TWITCH_DROP",
	featherhat_circus = "TWITCH_DROP",
	firesuppressor_circus = "TWITCH_DROP",
	fishbox_nautical = "TWITCH_DROP",
	glomling_puft = "ONI",
	hambat_nautical = "TWITCH_DROP",
	heatrock_fire = "TWITCH_DROP",
	icebox_crystal = "TWITCH_DROP",
	lantern_crystal = "TWITCH_DROP",
	lantern_winter = "WINTER",
	lantern_winter_alt = "WINTER",
	lightning_rod_nautical = "TWITCH_DROP",
	mast_crabking = "ROT2",
	mast_nautical = "TWITCH_DROP",
	mast_rose = "TOT",
	mastupgrade_lightningrod_nautical = "TWITCH_DROP",
	mastupgradelamp_nautical = "TWITCH_DROP",
	mysterybox_invisible_5 = "DEFAULT",
	mysterybox_terraria = "DEFAULT",
	mysterybox_ugly_3 = "WINTER",
	pack_hamlet_wormwood = "HAMLET",
	pack_hl_gift = "HOTLAVA",
	pack_oni_gift = "ONI",
	pack_rog_gift = "ROG",
	pack_sw_gift = "SW",
	playerportrait_bg_anchornautical = "TWITCH_DROP",
	playerportrait_bg_arrowsignpostcircus = "TWITCH_DROP",
	playerportrait_bg_beeboxcrystal = "TWITCH_DROP",
	playerportrait_bg_beefalohatklaus = "TWITCH_DROP",
	playerportrait_bg_birdcagecircus = "TWITCH_DROP",
	playerportrait_bg_coldfirepitteeth = "TWITCH_DROP",
	playerportrait_bg_dragonflychestkraken = "TWITCH_DROP",
	playerportrait_bg_dragonflyfurnacecrystal = "TWITCH_DROP",
	playerportrait_bg_eyebrellahatcrystal = "TWITCH_DROP",
	playerportrait_bg_featherhatcircus = "TWITCH_DROP",
	playerportrait_bg_firesuppressorcircus = "TWITCH_DROP",
	playerportrait_bg_fishboxnautical = "TWITCH_DROP",
	playerportrait_bg_foods = "GORGE",
	playerportrait_bg_hambatnautical = "TWITCH_DROP",
	playerportrait_bg_heatrockfire = "TWITCH_DROP",
	playerportrait_bg_iceboxcrystal = "TWITCH_DROP",
	playerportrait_bg_lanterncrystal = "TWITCH_DROP",
	playerportrait_bg_lightningrodnautical = "TWITCH_DROP",
	playerportrait_bg_mastnautical = "TWITCH_DROP",
	playerportrait_bg_mastupgradelampnautical = "TWITCH_DROP",
	playerportrait_bg_mastupgradelightningrodnautical = "TWITCH_DROP",
	playerportrait_bg_moonstarstaffcrystal = "TWITCH_DROP",
	playerportrait_bg_quagmiretournamentbronze = "GORGE_TOURNAMENT",
	playerportrait_bg_quagmiretournamentgold = "GORGE_TOURNAMENT",
	playerportrait_bg_quagmiretournamentsilver = "GORGE_TOURNAMENT",
	playerportrait_bg_rabbithouseyule = "TWITCH_DROP",
	playerportrait_bg_rainometercircus = "TWITCH_DROP",
	playerportrait_bg_researchlab2crystal = "TWITCH_DROP",
	playerportrait_bg_researchlab3crystal = "TWITCH_DROP",
	playerportrait_bg_researchlab3monster = "TWITCH_DROP",
	playerportrait_bg_researchlabgreen = "TWITCH_DROP",
	playerportrait_bg_saltboxnautical = "TWITCH_DROP",
	playerportrait_bg_saltboxshaker = "TWITCH_DROP",
	playerportrait_bg_steeringwheelnautical = "TWITCH_DROP",
	playerportrait_bg_telebasecrystal = "TWITCH_DROP",
	playerportrait_bg_telestaffcrystal = "TWITCH_DROP",
	playerportrait_bg_tentcircus = "TWITCH_DROP",
	playerportrait_bg_tophatcircus = "TWITCH_DROP",
	playerportrait_bg_torchnautical = "TWITCH_DROP",
	playerportrait_bg_umbrellacircus = "TWITCH_DROP",
	playerportrait_bg_wardrobecrystal = "TWITCH_DROP",
	playerportrait_bg_wardrobeyule = "TWITCH_DROP",
	playerportrait_bg_winterometercircus = "TWITCH_DROP",
	profileflair_anchor_nautical = "TWITCH_DROP",
	profileflair_arrowsignpost_circus = "TWITCH_DROP",
	profileflair_beebox_crystal = "TWITCH_DROP",
	profileflair_beefalohat_klaus = "TWITCH_DROP",
	profileflair_birdcage_circus = "TWITCH_DROP",
	profileflair_coldfirepit_teeth = "TWITCH_DROP",
	profileflair_dragonflychest_kraken = "TWITCH_DROP",
	profileflair_dragonflyfurnace_crystal = "TWITCH_DROP",
	profileflair_eyebrellahat_crystal = "TWITCH_DROP",
	profileflair_featherhat_circus = "TWITCH_DROP",
	profileflair_firesuppressor_circus = "TWITCH_DROP",
	profileflair_fishbox_nautical = "TWITCH_DROP",
	profileflair_hambat_nautical = "TWITCH_DROP",
	profileflair_heatrock_fire = "TWITCH_DROP",
	profileflair_icebox_crystal = "TWITCH_DROP",
	profileflair_lantern_crystal = "TWITCH_DROP",
	profileflair_lightningrodnautical = "TWITCH_DROP",
	profileflair_mast_nautical = "TWITCH_DROP",
	profileflair_mastupgradelamp_nautical = "TWITCH_DROP",
	profileflair_mastupgradelightningrod_nautical = "TWITCH_DROP",
	profileflair_quagmiretournament_bronze = "GORGE_TOURNAMENT",
	profileflair_quagmiretournament_gold = "GORGE_TOURNAMENT",
	profileflair_quagmiretournament_participation = "GORGE_TOURNAMENT",
	profileflair_quagmiretournament_silver = "GORGE_TOURNAMENT",
	profileflair_rabbithouse_yule = "TWITCH_DROP",
	profileflair_rainometer_circus = "TWITCH_DROP",
	profileflair_researchlab2_crystal = "TWITCH_DROP",
	profileflair_researchlab3_crystal = "TWITCH_DROP",
	profileflair_researchlab3_monster = "TWITCH_DROP",
	profileflair_researchlab_green = "TWITCH_DROP",
	profileflair_saltbox_shaker = "TWITCH_DROP",
	profileflair_saltboxnautical = "TWITCH_DROP",
	profileflair_starstaff_crystal = "TWITCH_DROP",
	profileflair_steeringwheel_nautical = "TWITCH_DROP",
	profileflair_telebase_crystal = "TWITCH_DROP",
	profileflair_telestaff_crystal = "TWITCH_DROP",
	profileflair_tent_circus = "TWITCH_DROP",
	profileflair_tophat_circus = "TWITCH_DROP",
	profileflair_torch_nautical = "TWITCH_DROP",
	profileflair_umbrella_circus = "TWITCH_DROP",
	profileflair_wardrobe_crystal = "TWITCH_DROP",
	profileflair_wardrobe_yule = "TWITCH_DROP",
	profileflair_winterometer_circus = "TWITCH_DROP",
	rabbithouse_yule = "TWITCH_DROP",
	rainometer_circus = "TWITCH_DROP",
	researchlab2_crystal = "TWITCH_DROP",
	researchlab3_crystal = "TWITCH_DROP",
	researchlab3_monster = "TWITCH_DROP",
	researchlab_green = "TWITCH_DROP",
	reviver_cupid = "CUPID",
	reviver_cupid_2 = "CUPID",
	reviver_cupid_3 = "CUPID",
	reviver_cupid_4 = "CUPID",
	saddle_basic_yotb = "YOTB",
	saddle_basic_yotbalt = "YOTB",
	saltbox_nautical = "TWITCH_DROP",
	saltbox_shaker = "TWITCH_DROP",
	starstaff_crystal = "TWITCH_DROP",
	steeringwheel_nautical = "TWITCH_DROP",
	telebase_crystal = "TWITCH_DROP",
	telestaff_crystal = "TWITCH_DROP",
	tent_circus = "TWITCH_DROP",
	tophat_circus = "TWITCH_DROP",
	torch_nautical = "TWITCH_DROP",
	torch_shadow = "ARG",
	torch_shadow_alt = "ARG",
	treasurechest_cupid = "CUPID",
	treasurechest_cupidalt = "CUPID",
	treasurechest_sacred = "ANRARG",
	umbrella_circus = "TWITCH_DROP",
	wardrobe_crystal = "TWITCH_DROP",
	wardrobe_yule = "TWITCH_DROP",
	winterhat_fancy_puppy = "VARG",
	winterhat_rooster = "LUNAR",
	winterometer_circus = "TWITCH_DROP",
}

local SKIN_GIFT_POPUPDATA =
{
	ANRARG =
	{
		atlas = "images/thankyou_anrarg.xml",
		image = "anrarg.tex",
		titleoffset = {0, -20, 0},
	},
	ARG =
	{
		atlas = "images/thankyou_gift.xml",
		image = "gift.tex",
		titleoffset = {0, -20, 0},
	},
	CUPID =
	{
		atlas = "images/thankyou_gift.xml",
		image = "gift.tex",
		titleoffset = {0, -30, 0},
	},
	DAILY_GIFT =
	{
		atlas = "images/thankyou_gift.xml",
		image = "gift.tex",
		titleoffset = {0, -20, 0},
	},
	DEFAULT =
	{
		atlas = "images/thankyou_gift.xml",
		image = "gift.tex",
		titleoffset = {0, -20, 0},
	},
	GORGE =
	{
		atlas = "images/thankyou_gorge.xml",
		image = "gorge.tex",
		titleoffset = {0, -20, 0},
	},
	GORGE_TOURNAMENT =
	{
		atlas = "images/thankyou_gift.xml",
		image = "gift.tex",
		titleoffset = {0, -20, 0},
	},
	HAMLET =
	{
		atlas = "images/thankyou_hamlet.xml",
		image = "hamlet.tex",
		titleoffset = {-120, 0, 0},
	},
	HOTLAVA =
	{
		atlas = "images/thankyou_hotlava.xml",
		image = "hotlava.tex",
		titleoffset = {0, -20, 0},
	},
	LUNAR =
	{
		atlas = "images/thankyou_lunar.xml",
		image = "lunar.tex",
		titleoffset = {0, -30, 0},
	},
	ONI =
	{
		atlas = "images/thankyou_oni.xml",
		image = "oni.tex",
		titleoffset = {0, -20, 0},
	},
	ROG =
	{
		atlas = "images/thankyou_rog_1.xml",
		image = "rog_1.tex",
		titleoffset = {-70, 0, 0},
	},
	ROGR =
	{
		atlas = "images/thankyou_rog_1.xml",
		image = "rog_1.tex",
		title_size = 40,
		titleoffset = {-90, 0, 0},
	},
	ROT2 =
	{
		atlas = "images/thankyou_rot.xml",
		image = "rot.tex",
		titleoffset = {0, -20, 0},
	},
	STORE =
	{
		atlas = "images/thankyou_gift.xml",
		image = "gift.tex",
		titleoffset = {0, -20, 0},
	},
	SW =
	{
		atlas = "images/thankyou_sw.xml",
		image = "sw.tex",
		titleoffset = {-140, 0, 0},
	},
	SWR =
	{
		atlas = "images/thankyou_sw.xml",
		image = "sw.tex",
		title_size = 40,
		titleoffset = {-135, 0, 0},
	},
	TOT =
	{
		atlas = "images/thankyou_rot.xml",
		image = "rot.tex",
		titleoffset = {0, -20, 0},
	},
	TWITCH =
	{
		atlas = "images/thankyou_twitch.xml",
		image = "twitch.tex",
		titleoffset = {0, -20, 0},
	},
	TWITCH_DROP =
	{
		atlas = "images/thankyou_twitch.xml",
		image = "twitch.tex",
		titleoffset = {0, -20, 0},
	},
	VARG =
	{
		atlas = "images/thankyou_varg.xml",
		image = "varg.tex",
		titleoffset = {0, -20, 0},
	},
	WINTER =
	{
		atlas = "images/thankyou_winter.xml",
		image = "winter.tex",
		titleoffset = {0, -30, 0},
	},
	YOTB =
	{
		atlas = "images/thankyou_yotb.xml",
		image = "yotb.tex",
		titleoffset = {0, -20, 0},
	},
	YOTP =
	{
		atlas = "images/thankyou_yotp.xml",
		image = "yotp.tex",
		titleoffset = {0, -20, 0},
	},
}

return { types = SKIN_GIFT_TYPES, popupdata = SKIN_GIFT_POPUPDATA }
