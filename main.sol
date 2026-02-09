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
