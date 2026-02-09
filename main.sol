// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Alien Vista — In-game NFT collection for vista-bound entities and species
/// @notice ERC-721 style collection with mint phases, on-chain trait slots for game use, and EIP-2981 royalties.
/// @custom:inspiration Procedural terrain and vista seeds; each token carries a deterministic vista seed for runtime generation.
contract AlienVista {
    // ─── Phase and supply ────────────────────────────────────────────────────────
    event Transfer(address indexed fromAddr, address indexed toAddr, uint256 indexed tokenId);
    event Approval(address indexed holder, address indexed operator, uint256 indexed tokenId);
    event ApprovalForAll(address indexed holder, address indexed operator, bool status);

    event VistaMinted(address indexed to, uint256 indexed tokenId, uint256 vistaSeed, uint8 speciesSlot);
    event PhaseAdvanced(uint8 fromPhase, uint8 toPhase, uint256 atBlock);
    event VistaRevealed(uint256 indexed tokenId, bytes32 traitCommit);
    event RoyaltySet(address indexed payee, uint16 bps);

    error Vista_NotMinter();
    error Vista_SupplyExhausted();
    error Vista_PhaseClosed();
    error Vista_OverWalletCap();
    error Vista_Underpaid();
    error Vista_ZeroReceiver();
    error Vista_InvalidToken();
    error Vista_NotOwnerNorApproved();
    error Vista_TransferToZero();
    error Vista_ApproveToCaller();
    error Vista_WrongFrom();
    error Vista_RoyaltyBpsTooHigh();
    error Vista_Reentrancy();
    error Vista_InvalidPhase();
    error Vista_InvalidSpeciesSlot();

    uint256 public constant CAP = 7777;
    uint256 public constant MINT_WEI = 0.007 ether;
    uint256 public constant MAX_PER_WALLET = 5;
    uint256 public constant PHASE_DURATION_BLOCKS = 2100;
    uint256 public constant MAX_ROYALTY_BPS = 1200;
    uint256 public constant SPECIES_SLOT_MAX = 15;

    bytes4 private constant _ERC2981_SELECTOR = 0x2a55205a;

    address public immutable minter;
    address public immutable treasury;
    address public immutable gameBridge;
    address public immutable metadataGate;

    uint256 public immutable phaseZeroBlock;

    uint256 private _nextId = 1;
    uint256 private _totalMinted;
    uint256 private _reentrancyGuard;
    string private _baseURI;
    address private _royaltyPayee;
    uint16 private _royaltyBps;

    uint8 public currentPhase;

    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => address) private _tokenApproval;
    mapping(address => mapping(address => bool)) private _operatorApproval;
    mapping(uint256 => VistaRecord) private _vistaData;
    mapping(address => uint256) private _mintCountByWallet;

