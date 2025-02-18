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

import {ScriptTools} from "dss-test/ScriptTools.sol";
import {DSPC} from "../DSPC.sol";
import {DSPCMom} from "../DSPCMom.sol";
import {DSPCInstance} from "./DSPCInstance.sol";

struct DSPCDeployParams {
    address deployer;
    address owner;
    address jug;
    address pot;
    address susds;
    address conv;
}

library DSPCDeploy {
    function deploy(DSPCDeployParams memory params) internal returns (DSPCInstance memory inst) {
        inst.dspc = new DSPC(params.jug, params.pot, params.susds, params.conv);

        inst.mom = new DSPCMom();

        ScriptTools.switchOwner(address(inst.dspc), params.deployer, params.owner);
        inst.mom.setOwner(params.owner);
    }
}
