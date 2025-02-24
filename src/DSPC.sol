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

interface JugLike {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function ilks(bytes32 ilk) external view returns (uint256 duty, uint256 rho);
    function drip(bytes32 ilk) external;
}

interface PotLike {
    function file(bytes32 what, uint256 data) external;
    function dsr() external view returns (uint256);
    function drip() external;
}

interface SUSDSLike {
    function file(bytes32 what, uint256 data) external;
    function ssr() external view returns (uint256);
    function drip() external;
}

interface ConvLike {
    function btor(uint256 bps) external pure returns (uint256 ray);
    function rtob(uint256 ray) external pure returns (uint256 bps);
}

/// @title Direct Stability Parameters Change Module
/// @notice A module that allows direct changes to stability parameters with constraints
/// @dev This contract manages stability parameters for ilks, DSR, and SSR with configurable limits
/// @custom:authors [Oddaf]
/// @custom:reviewers []
/// @custom:auditors []
/// @custom:bounties []
contract DSPC {
    // --- Structs ---
    struct Cfg {
        uint16 min; // Minimum rate in basis points
        uint16 max; // Maximum rate in basis points
        uint16 step; // Maximum rate change in basis points
    }

    struct ParamChange {
        bytes32 id; // Identifier (ilk | "DSR" | "SSR")
        uint256 bps; // New rate in basis points
    }

    // --- Immutables ---
    /// @notice Stability fee rates
    JugLike public immutable jug;
    /// @notice DSR rate
    PotLike public immutable pot;
    /// @notice SSR rate
    SUSDSLike public immutable susds;
    /// @notice Rate conversion utility
    ConvLike public immutable conv;

    // --- Storage Variables ---
    /// @notice Mapping of admin addresses
    mapping(address => uint256) public wards;
    /// @notice Mapping of addresses that can operate this module
    mapping(address => uint256) public buds;
    /// @notice Mapping of rate constraints
    mapping(bytes32 => Cfg) private _cfgs;
    /// @notice Circuit breaker flag
    uint256 public bad;
    /// @notice Cooldown period between rate changes in seconds
    uint256 public tau;
    /// @notice Last time when rates were updated (Unix timestamp)
    uint256 public toc;

    // --- Events ---
    /**
     * @notice `usr` was granted admin access.
     * @param usr The user address.
     */
    event Rely(address indexed usr);
    /**
     * @notice `usr` admin access was revoked.
     * @param usr The user address.
     */
    event Deny(address indexed usr);
    /**
     * @notice `usr` was granted permission to change rates (call set()).
     * @param usr The user address.
     */
    event Kiss(address indexed usr);
    /**
     * @notice Permission revoked for `usr` to change rates (call set()).
     * @param usr The user address.
     */
    event Diss(address indexed usr);
    /**
     * @notice A contract parameter was updated.
     * @param what The changed parameter name. ["bad"].
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed what, uint256 data);
    /**
     * @notice A Ilk/DSR/SSR parameter was updated.
     * @param id The Ilk/DSR/SSR identifier.
     * @param what The changed parameter name. ["bad"].
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed id, bytes32 indexed what, uint256 data);
    /**
     * @notice Rate change was executed.
     * @param id The Ilk/DSR/SSR identifier.
     * @param bps The new value of the rate in basis points.
     */
    event Set(bytes32 indexed id, uint256 bps);

    // --- Modifiers ---
    modifier auth() {
        require(wards[msg.sender] == 1, "DSPC/not-authorized");
        _;
    }

    modifier toll() {
        require(buds[msg.sender] == 1, "DSPC/not-facilitator");
        _;
    }

    modifier good() {
        require(bad == 0, "DSPC/module-halted");
        _;
    }

    /// @notice Constructor sets the core contracts
    /// @param _jug The Jug contract for managing stability fees
    /// @param _pot The Pot contract for managing DSR
    /// @param _susds The SUSDS contract for managing SSR
    /// @param _conv The conversion utility contract for rate calculations
    constructor(address _jug, address _pot, address _susds, address _conv) {
        jug = JugLike(_jug);
        pot = PotLike(_pot);
        susds = SUSDSLike(_susds);
        conv = ConvLike(_conv);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- Administration ---
    /// @notice Grant authorization to an address
    /// @param usr The address to be authorized
    /// @dev Sets wards[usr] to 1 and emits Rely event
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    /// @notice Revoke authorization from an address
    /// @param usr The address to be deauthorized
    /// @dev Sets wards[usr] to 0 and emits Deny event
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    /// @notice Add a facilitator
    /// @param usr The address to add as a facilitator
    /// @dev Sets buds[usr] to 1 and emits Kiss event. Facilitators can propose rate updates but cannot modify system parameters
    function kiss(address usr) external auth {
        buds[usr] = 1;
        emit Kiss(usr);
    }

    /// @notice Remove a facilitator
    /// @param usr The address to remove as a facilitator
    /// @dev Sets buds[usr] to 0 and emits Diss event
    function diss(address usr) external auth {
        buds[usr] = 0;
        emit Diss(usr);
    }

    /// @notice Configure module parameters
    /// @param what The parameter to configure
    /// @param data The value to set
    /// @dev Emits File event after successful configuration
    function file(bytes32 what, uint256 data) external auth {
        if (what == "bad") {
            require(data <= 1, "DSPC/invalid-bad-value");
            bad = data;
        } else if (what == "tau") {
            tau = data;
        } else {
            revert("DSPC/file-unrecognized-param");
        }

        emit File(what, data);
    }

    /// @notice Configure constraints for a rate
    /// @param id The rate identifier (ilk name, "DSR", or "SSR")
    /// @param what The parameter to configure ("min", "max" or "step")
    /// @param data The value to set
    /// @dev Emits File event after successful configuration
    function file(bytes32 id, bytes32 what, uint256 data) external auth {
        require(data <= type(uint16).max, "DSPC/invalid-value");
        if (what == "min") {
            require(data <= _cfgs[id].max, "DSPC/min-too-high");
            _cfgs[id].min = uint16(data);
        } else if (what == "max") {
            require(data >= _cfgs[id].min, "DSPC/max-too-low");
            _cfgs[id].max = uint16(data);
        } else if (what == "step") {
            _cfgs[id].step = uint16(data);
        } else {
            revert("DSPC/file-unrecognized-param");
        }

        emit File(id, what, data);
    }

    /// @notice Apply rate updates
    /// @param updates Array of rate updates to apply
    /// @dev Each update is validated against configured constraints before being applied
    /// @dev Emits Set event after all updates are successfully applied
    /// @dev Reverts if:
    ///      - Empty updates array
    ///      - Cooldown not expired
    ///      - Rate below configured minimum
    ///      - Rate above configured maximum
    ///      - Rate change above configured step
    function set(ParamChange[] calldata updates) external toll good {
        require(updates.length > 0, "DSPC/empty-batch");
        require(block.timestamp >= tau + toc, "DSPC/too-early");
        toc = block.timestamp;

        // Validate all updates in the batch
        for (uint256 i = 0; i < updates.length; i++) {
            bytes32 id = updates[i].id;
            uint256 bps = updates[i].bps;
            Cfg memory cfg = _cfgs[id];

            require(bps >= cfg.min, "DSPC/below-min");
            require(bps <= cfg.max, "DSPC/above-max");

            // Check rate change is within allowed gap
            uint256 oldBps;
            if (id == "DSR") {
                oldBps = conv.rtob(PotLike(pot).dsr());
            } else if (id == "SSR") {
                oldBps = conv.rtob(SUSDSLike(susds).ssr());
            } else {
                (uint256 duty,) = JugLike(jug).ilks(id);
                oldBps = conv.rtob(duty);
            }

            // Calculates absolute difference between the old and the new rate
            uint256 delta = bps > oldBps ? bps - oldBps : oldBps - bps;
            require(delta <= cfg.step, "DSPC/delta-above-step");

            // Execute the update
            uint256 ray = conv.btor(bps);
            if (id == "DSR") {
                pot.drip();
                pot.file("dsr", ray);
            } else if (id == "SSR") {
                susds.drip();
                susds.file("ssr", ray);
            } else {
                jug.drip(id);
                jug.file(id, "duty", ray);
            }
            emit Set(id, bps);
        }
    }

    // --- Getters ---
    /// @notice Get configuration for a rate
    /// @param id The rate identifier (ilk name, "DSR", or "SSR")
    /// @return The configuration struct containing min and max values
    /// @dev Returns a Cfg struct with min and max values for the specified rate
    function cfgs(bytes32 id) external view returns (Cfg memory) {
        return _cfgs[id];
    }
}
