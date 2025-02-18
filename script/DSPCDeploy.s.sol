// SPDX-FileCopyrightText: © 2025 Dai Foundation <www.daifoundation.org>
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

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {MCD, DssInstance} from "dss-test/MCD.sol";
import {ScriptTools} from "dss-test/ScriptTools.sol";
import {DSPCDeploy, DSPCDeployParams} from "src/deployment/DSPCDeploy.sol";
import {DSPCInstance} from "src/deployment/DSPCInstance.sol";

contract DSPCDeployScript is Script {
    using stdJson for string;
    using ScriptTools for string;

    string constant NAME = "dspc-deploy";
    string config;

    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    DssInstance dss = MCD.loadFromChainlog(CHAINLOG);
    address pauseProxy = dss.chainlog.getAddress("MCD_PAUSE_PROXY");
    address conv;
    DSPCInstance inst;

    function run() external {
        config = ScriptTools.loadConfig();
        conv = config.readAddress(".conv", "FOUNDRY_CONV");

        vm.startBroadcast();

        inst = DSPCDeploy.deploy(
            DSPCDeployParams({
                deployer: msg.sender,
                owner: pauseProxy,
                jug: address(dss.jug),
                pot: address(dss.pot),
                susds: dss.chainlog.getAddress("SUSDS"),
                conv: conv
            })
        );

        vm.stopBroadcast();

        ScriptTools.exportContract(NAME, "dspc", address(inst.dspc));
        ScriptTools.exportContract(NAME, "mom", address(inst.mom));
        ScriptTools.exportContract(NAME, "conv", conv);
    }
}
