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

    struct VistaRecord {
        uint256 vistaSeed;
        uint8 speciesSlot;
        bytes32 traitCommit;
        bool revealed;
    }

    constructor() {
        minter = address(0x3C4d5E6f7A8b9c0D1e2F3a4B5c6D7e8F9a0B1C2d3);
        treasury = address(0x4D5e6F7a8B9c0d1E2f3A4b5C6d7E8f9A0b1C2d3E4);
        gameBridge = address(0x5E6f7A8b9C0d1e2F3a4B5c6D7e8F9a0B1c2D3e4F5);
        metadataGate = address(0x6F7a8B9c0D1e2f3A4b5C6d7E8f9A0b1C2d3E4f5A6);

        phaseZeroBlock = block.number;
        currentPhase = 1;

        _baseURI = "https://alien-vista.example/metadata/";
        _royaltyPayee = treasury;
        _royaltyBps = 600;
    }

    modifier onlyMinter() {
        if (msg.sender != minter) revert Vista_NotMinter();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyGuard != 0) revert Vista_Reentrancy();
        _reentrancyGuard = 1;
        _;
        _reentrancyGuard = 0;
    }

    function mint(address to, uint8 speciesSlot) external payable onlyMinter nonReentrant returns (uint256 tokenId) {
        if (to == address(0)) revert Vista_ZeroReceiver();
        if (_totalMinted >= CAP) revert Vista_SupplyExhausted();
        if (speciesSlot > SPECIES_SLOT_MAX) revert Vista_InvalidSpeciesSlot();
        if (msg.value < MINT_WEI) revert Vista_Underpaid();
        if (_mintCountByWallet[to] >= MAX_PER_WALLET) revert Vista_OverWalletCap();

        uint256 phaseLimit = _phaseSupplyCap(currentPhase);
        if (_totalMinted >= phaseLimit) revert Vista_PhaseClosed();

        tokenId = _nextId++;
        _totalMinted += 1;
        _mintCountByWallet[to] += 1;

        uint256 vistaSeed = uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, tokenId, to)));
        _vistaData[tokenId] = VistaRecord({
            vistaSeed: vistaSeed,
            speciesSlot: speciesSlot,
            traitCommit: bytes32(0),
            revealed: false
        });

        _ownerOf[tokenId] = to;
        _balanceOf[to] += 1;

        (bool sent,) = treasury.call{ value: msg.value }("");
        require(sent, "Vista: treasury send failed");

        emit Transfer(address(0), to, tokenId);
        emit VistaMinted(to, tokenId, vistaSeed, speciesSlot);
        return tokenId;
    }

    function revealTraits(uint256 tokenId, bytes32 traitCommit) external onlyMinter {
        if (_ownerOf[tokenId] == address(0)) revert Vista_InvalidToken();
        VistaRecord storage rec = _vistaData[tokenId];
        if (rec.revealed) revert Vista_InvalidToken();
        rec.traitCommit = traitCommit;
        rec.revealed = true;
        emit VistaRevealed(tokenId, traitCommit);
    }

    function advancePhase() external onlyMinter {
        uint8 next = currentPhase + 1;
        if (next > 4) revert Vista_InvalidPhase();
        uint8 prev = currentPhase;
        currentPhase = next;
        emit PhaseAdvanced(prev, next, block.number);
    }

    function setBaseURI(string calldata uri) external onlyMinter {
        _baseURI = uri;
    }

    function setRoyalty(address payee, uint16 bps) external onlyMinter {
        if (bps > MAX_ROYALTY_BPS) revert Vista_RoyaltyBpsTooHigh();
        _royaltyPayee = payee;
        _royaltyBps = bps;
