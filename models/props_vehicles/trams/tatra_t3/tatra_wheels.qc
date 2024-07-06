$modelname "tatra_wheels.mdl"

$bodygroup "studio"
{
	studio "tatra_wheels.smd"
}

$surfaceprop "metal"

$contents "solid"

$cdmaterials "models\props_vehicles\trams\tatra_t3\"

$cbox 0 0 0 0 0 0

$bbox -69.242 -43.305 -22.003 69.255 43.305 22.003

$definebone "root" "" 0 0 0 0 0 0 0 0 0 0 0 0


$sequence "idle" {
	"tatra_wheels_anims\idle.smd"
	fadein 0.2
	fadeout 0.2
	fps 30
}

$collisionmodel "tatra_wheels_physics.smd"
{
	$mass 2500
	$inertia 1
	$damping 0
	$rotdamping 0
	$rootbone " "
	$concave
	$maxconvexpieces 8

}
