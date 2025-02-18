// SPDX-FileCopyrightText: © 2023 Dai Foundation <www.daifoundation.org>
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

import {DssInstance} from "dss-test/MCD.sol";
import {DSPCInstance} from "./DSPCInstance.sol";

interface SUSDSLike {
    function rely(address usr) external;
}

library DSPCInit {
    /**
     * @dev Initializes a DSPC instance.
     * @param dss The DSS instance.
     * @param inst The DSCP instance.
     */
    function init(DssInstance memory dss, DSPCInstance memory inst) internal {
        inst.dspc.rely(address(inst.mom));
        inst.mom.setAuthority(dss.chainlog.getAddress("MCD_ADM"));

        dss.jug.rely(address(inst.dspc));
        dss.pot.rely(address(inst.dspc));
        SUSDSLike(dss.chainlog.getAddress("SUSDS")).rely(address(inst.dspc));
    }
}
