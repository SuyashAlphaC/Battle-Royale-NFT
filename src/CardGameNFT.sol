// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract CardBattleGame is Ownable, EIP712 {
    IERC721Enumerable public nftCollection;

    uint256 public nextBattleId;

    enum CharacterClass { BARBARIAN, KNIGHT, RANGER, ROGUE, WIZARD, CLERIC }


    struct Player {
        string name;
        address playerAddress;
        uint256 totalWins;
        uint256 totalLosses; 
        uint256 experience;  
        mapping(uint256 => CharacterStats) characterStats; 
    }

    struct CharacterStats {
        CharacterClass class;
        uint256 level;
        uint256 exp;
        uint256 health;
        uint8 mana;
        uint256 attack;
        uint256 defense;
        uint256 wins;
        uint256 losses;
    }


    struct Battle {
        string name;
        address player1;
        address player2;
        uint256 player1TokenId;
        uint256 player2TokenId;
        uint256 startTime;
        bool resolved;
    }

    bytes32 private constant RESOLVE_BATTLE_TYPEHASH = keccak256("ResolveBattle(uint256 battleId,address _player2, bool isComputer,uint256 _player1TokenId,uint256 _player2TokenId,address _winner,uint256 _winnerExp,uint256 _loserExp)");    uint256 public totalBattle;
    mapping(address => Player) public players;
    mapping(uint256 => Battle) public battles;

    event PlayerRegistered(address indexed playerAddress, string name);
    event BattleRegistered(uint256 indexed battleId, string name, address indexed player1);
    event BattleResolved(uint256 indexed battleId, address indexed winner, address indexed loser, uint256 winnerExp, uint256 loserExp);

    error CardGameNFT__InvalidClass();

    constructor(address _nftCollectionAddress) EIP712("CardBattleGame", "1") Ownable(msg.sender) {
        nftCollection = IERC721Enumerable(_nftCollectionAddress);
        totalBattle = 0;
        nextBattleId = 1;
    }

    function registerPlayer(string memory _name) external {
        require (bytes(players[msg.sender].name).length == 0, "Player Already Exists!!");
        players[msg.sender].name = _name;
        players[msg.sender].playerAddress = msg.sender;

        emit PlayerRegistered(msg.sender, _name);

    }

    function registerBattle(string memory _battleName) external returns (uint256) {
        uint battleId = nextBattleId++ ;
        battles[battleId] = Battle ({
            name: _battleName,
            player1: msg.sender,
            player2: address(0),
            player1TokenId: 0,
            player2TokenId: 0,
            startTime: block.timestamp,
            resolved: false
        });
        totalBattle ++ ;
        emit BattleRegistered(battleId,_battleName, msg.sender);
        return battleId;
    }

    function resolveBattle(
        uint256 _battleId,
        address _player2,
        bool isComputer,
        uint256 _player1TokenId,
        uint256 _player2TokenId,
        address _winner,
        uint256 _winnerExp,
        uint256 _loserExp,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        Battle storage battle = battles[_battleId];
        require(!battle.resolved, "Battle already resolved");
        require(_player2 != address(0), "Invalid player2 Address");
        require(battle.player2 == address(0), "Battle already has a second address");
        require(nftCollection.ownerOf(_player1TokenId) == battle.player1, "Player1 must own the specific NFT");

        if(!isComputer) {
            require(nftCollection.ownerOf(_player2TokenId) == battle.player2, "Player2 must own the specific NFT");
        }

        bytes32 structHash = keccak256(abi.encode(RESOLVE_BATTLE_TYPEHASH, _battleId, _player2, isComputer, _player1TokenId, _player2TokenId, _winner, _winnerExp, _loserExp));
        bytes32 hash = _hashTypedDataV4(structHash);
        require(ecrecover(hash, v, r, s) == owner(), "Invalid signature");

        battle.player2 = _player2;
        battle.player1TokenId = _player1TokenId;
        battle.player2TokenId = _player2TokenId;
        battle.resolved = true;  //ASSIGNMENT #5

        _updateBattleStats(_battleId, _winner, _winnerExp, _loserExp);

        emit BattleResolved(_battleId, _winner, _winner == battle.player1 ? _player2 : battle.player1, _winnerExp, _loserExp);
    }

    function _updateBattleStats(uint256 _battleId, address _winner, uint256 _winnerExp, uint256 _loserExp) private {
         Battle storage battle = battles[_battleId];
        address loser = (_winner == battle.player1) ? battle.player2 : battle.player1;
        uint256 winnerTokenId = (_winner == battle.player1) ? battle.player1TokenId : battle.player2TokenId;
        uint256 loserTokenId = (_winner == battle.player1) ? battle.player2TokenId : battle.player1TokenId;

        // Update winner stats
        CharacterStats storage winnerStats = players[_winner].characterStats[winnerTokenId];
        winnerStats.exp += _winnerExp;
        winnerStats.wins ++ ; 
        players[_winner].totalWins++;
        players[_winner].experience += _winnerExp;

        // Update loser stats
        CharacterStats storage loserStats = players[loser].characterStats[loserTokenId];
        loserStats.exp += _loserExp;
        loserStats.losses++;
        players[loser].totalLosses++ ; 
        players[loser].experience += _loserExp;

        // Level up logic
        _levelUp(winnerStats);
        _levelUp(loserStats);
    }
    

    function _levelUp(CharacterStats storage stats) private {
         while (stats.exp >= getRequiredExp(stats.level)) {
            stats.level++;
        }
    }

    // Helper functions
    function isPlayer(address addr) public view returns (bool) {
        return bytes(players[addr].name).length > 0;
    }

    function getBaseHealth(CharacterClass _class) public pure returns (uint256) {
        if (_class == CharacterClass.BARBARIAN) return 150;
        if(_class == CharacterClass.KNIGHT) return 120;
        if(_class == CharacterClass.RANGER) return 100;
        if(_class == CharacterClass.ROGUE) return 90;
        if(_class == CharacterClass.WIZARD) return 80;
        if(_class == CharacterClass.CLERIC) return 110;
        revert ("Invalid Class");
    }

    function getBaseMana(CharacterClass _class) public pure returns (uint256) {
        if (_class == CharacterClass.BARBARIAN) return 50;
        if(_class == CharacterClass.KNIGHT) return 60;
        if(_class == CharacterClass.RANGER) return 70;
        if(_class == CharacterClass.ROGUE) return 60;
        if(_class == CharacterClass.WIZARD) return 100;
        if(_class == CharacterClass.CLERIC) return 90;
        revert ("Invalid Class");
    }

    function getBaseAttack(CharacterClass _class) public pure returns (uint256) {
        if (_class == CharacterClass.BARBARIAN) return 85;
        if(_class == CharacterClass.KNIGHT) return 95;
        if(_class == CharacterClass.RANGER) return 120;
        if(_class == CharacterClass.ROGUE) return 90;
        if(_class == CharacterClass.WIZARD) return 82;
        if(_class == CharacterClass.CLERIC) return 105;
        revert ("Invalid Class");      
    }

    function getBaseDefense(CharacterClass _class) public pure returns (uint256) {
        if (_class == CharacterClass.BARBARIAN) return 130;
        if(_class == CharacterClass.KNIGHT) return 95;
        if(_class == CharacterClass.RANGER) return 125;
        if(_class == CharacterClass.ROGUE) return 110;
        if(_class == CharacterClass.WIZARD) return 95;
        if(_class == CharacterClass.CLERIC) return 95;
        revert ("Invalid Class");
    }

    function getCharacterStats(address _player, uint256 _tokenId) external view returns (CharacterStats memory) {
        require(nftCollection.ownerOf(_tokenId) == _player, "CardBattleGame: Invalid token id");
        return players[_player].characterStats[_tokenId];
    }

    function getRequiredExp(uint256 _level) public pure returns (uint256) {
        return _level * 100;
    }
}
