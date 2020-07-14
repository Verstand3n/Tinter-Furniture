//Mission settings to tweak
#define RANGE 300
#define FREQUENCY 10
#define SEED 42
#define LIMIT 42

tint_range = RANGE;
tint_seed = SEED;

call compile preprocessFileLineNumbers "furniture\import.sqf";

// no HC or dedicated server allowed
if !(hasInterface) exitWith {
  ["tint_dressDownServer", {
    [{
      params ["_houses"];
      {
        [_x] call tint_fnc_dressDown_server;
      } forEach _houses;
    }, _this] call CBA_fnc_execNextFrame;
  }] call CBA_fnc_addEventHandler;
  ["tint_dressUpServer", {
    [{
      params ["_houses"];
      {
        [_x] call tint_fnc_dressUp_server;
      } forEach _houses;
    }, _this] call CBA_fnc_execNextFrame;
  }] call CBA_fnc_addEventHandler;
};

tint_activeHouses = [];
tint_dressUpHouses = [];
tint_dressDownHouses = [];

#include "..\buildings.hpp";

//Sleep because scheduler? Makes furniture show up faster initially
sleep 0.1;

//Building finding loop
[_validBuildings] spawn {
  params ["_validBuildings"];
  tint_houses = true;

  // private _activeHouses = tint_activeHouses;
  while {tint_houses} do {
    private _pos = positionCameraToWorld [0,0,0];
    private _buildings = (_pos nearObjects ["House_F", RANGE]) select {!(isObjectHidden _x) && {!(_x getVariable ["tint_house_blacklisted", false])} && {alive _x}};

    //Remove all buildings not a child of the chosen classes
    {
      private _house = _x;
      private _index = _validBuildings findif {_house isKindOf _x};
      if (_index != -1) then {
        tint_activeHouses pushBackUnique _house;
        _house setVariable ["tint_house_class", _validBuildings#_index];
      };
    } forEach _buildings;
    tint_activeHouses = [tint_activeHouses, [_pos], {_input0 distance _x}, "ASCEND"] call BIS_fnc_sortBy;
    
    private _dressUpServer = [];
    private _dressDownServer = [];
    
    
    for "_i" from 0 to (LIMIT-1 min (count tint_activeHouses - 1)) do {
      private _house = tint_activeHouses#_i;
      if !(_house getVariable ["tint_house_dressed", false]) then {
        tint_dressUpHouses pushBack _house;
        _dressUpServer pushBack _house;
      };
    };
    
    for "_i" from (count tint_activeHouses - 1) to (LIMIT) step -1 do {
      private _house = tint_activeHouses#_i;
      if (_house getVariable ["tint_house_dressed", false]) then {
        tint_dressDownHouses pushBack _house;
        _dressDownServer pushBack _house;
      };
      tint_activeHouses deleteAt _i;
    };

    if (isMultiplayer) then {
      if (count _dressDownServer > 0) then {
        //Tell server to delete
        ["tint_dressDownServer", [_dressDownServer]] call CBA_fnc_globalEvent;
      };
      if (count _dressUpServer > 0) then {
        //Spawn on the server to keep ai working
        ["tint_dressUpServer", [_dressDownServer]] call CBA_fnc_globalEvent;
      };
    };

    sleep FREQUENCY;
  };
};

//House dressing loop
[] spawn {
  tint_houses = true;

  while {tint_houses} do {
    if (count tint_dressUpHouses > 0) then {
      [tint_dressUpHouses#0] call tint_fnc_dressUp;
      tint_dressUpHouses deleteAt 0;
    } else {
      if (count tint_dressDownHouses > 0) then {
        [tint_dressDownHouses#0] call tint_fnc_dressDown;
        tint_dressDownHouses deleteAt 0;
      }
    };
    
    //Let's the scheduler sleep, hopefully avoiding any lag spikes while not having a noticeable pause
    sleep 0.05;
  };
};