// SPDX-FileCopyrightText: 2025 Dai Foundation <www.daifoundation.org>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.24;

interface AuthorityLike {
    function canCall(address src, address dst, bytes4 sig) external view returns (bool);
}

interface DSPCLike {
    function file(bytes32 what, uint256 data) external;
}

/// @title DSPC Mom - Emergency shutdown for DSPC
/// @notice A contract that can halt the DSPC module in case of emergency
/// @custom:authors [Oddaf]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract DSPCMom {
    // --- Auth ---
    address public owner; // Owner address
    address public authority; // Authorization contract

    // --- Events ---
    event SetOwner(address indexed owner);
    event SetAuthority(address indexed authority);
    event Halt(address indexed dspc);

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "DSPCMom/not-owner");
        _;
    }

    modifier auth() {
        require(isAuthorized(msg.sender, msg.sig), "DSPCMom/not-authorized");
        _;
    }

    /// @notice Constructor sets initial owner
    constructor() {
        owner = msg.sender;
        emit SetOwner(msg.sender);
    }

    // --- Administration ---
    /// @notice Set a new owner
    /// @param owner_ The new owner address
    function setOwner(address owner_) external onlyOwner {
        owner = owner_;
        emit SetOwner(owner_);
    }

    /// @notice Set the authority contract
    /// @param authority_ The new authority contract
    function setAuthority(address authority_) external onlyOwner {
        authority = authority_;
        emit SetAuthority(authority_);
    }

    // --- Internal Functions ---
    /// @notice Check if an address is authorized to call a function
    /// @param src The source address making the call
    /// @param sig The function signature being called
    /// @return Whether the address is authorized
    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == owner || src == address(this)) {
            return true;
        } else if (authority != address(0)) {
            return AuthorityLike(authority).canCall(src, address(this), sig);
        } else {
            return false;
        }
    }

    // --- Emergency Actions ---
    /// @notice Halt the DSPC module without enforcing the GSM delay
    /// @param dspc The DSPC contract to halt
    function halt(address dspc) external auth {
        DSPCLike(dspc).file("bad", 1);
        emit Halt(dspc);
    }
}
