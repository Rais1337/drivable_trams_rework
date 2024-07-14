// Created by Crowbar 0.67

$modelname "t6b5.mdl"

$bodygroup "studio"
{
	studio "t6b5.smd"
}
$bodygroup "bench"
{
	studio "siduhi.smd"
	blank
}


$surfaceprop "metalvehicle"

$contents "solid"

$illumposition 2.823 1.519 16.685

$cdmaterials "models\drivtrams\tatra_t6b5su\"
$cdmaterials "models\drivtrams\other\"

$cbox 0 0 0 0 0 0

$bbox -367.231 -67.801 -80.006 352.75 68.178 113.3

$definebone "kHED" "" 0 0 0 0 0 0 0 0 0 0 0 0


$sequence "idle" {
	"tatra_t6b5_anims\idle.smd"
	fadein 0.2
	fadeout 0.2
	fps 30
}

$collisionmodel "tatra_t6b5_physics.smd"
{
	$mass 20000
	$inertia 1
	$damping 0
	$rotdamping 0
	$rootbone " "
	$concave
	$maxconvexpieces 24

}
