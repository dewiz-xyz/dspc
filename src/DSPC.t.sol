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

import "dss-test/DssTest.sol";
import {DSPC} from "./DSPC.sol";
import {DSPCMom} from "./DSPCMom.sol";
import {ConvMock} from "./mocks/ConvMock.sol";
import {DSPCDeploy, DSPCDeployParams} from "./deployment/DSPCDeploy.sol";
import {DSPCInit} from "./deployment/DSPCInit.sol";
import {DSPCInstance} from "./deployment/DSPCInstance.sol";

interface ConvLike {
    function btor(uint256 bps) external pure returns (uint256 ray);
    function rtob(uint256 ray) external pure returns (uint256 bps);
}

interface SUSDSLike {
    function wards(address usr) external view returns (uint256);
    function ssr() external view returns (uint256);
}

interface ProxyLike {
    function exec(address usr, bytes memory fax) external returns (bytes memory out);
}

contract InitCaller {
    function init(DssInstance memory dss, DSPCInstance memory inst) external {
        DSPCInit.init(dss, inst);
    }
}

contract DSPCTest is DssTest {
    address constant CHAINLOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance dss;
    DSPC dspc;
    DSPCMom mom;
    ConvLike conv;
    SUSDSLike susds;
    address pause;
    ProxyLike pauseProxy;
    InitCaller caller;
    address bud = address(0xb0d);

    bytes32 constant ILK = "ETH-A";
    bytes32 constant DSR = "DSR";
    bytes32 constant SSR = "SSR";

    event Kiss(address indexed usr);
    event Diss(address indexed usr);
    event File(bytes32 indexed id, bytes32 indexed what, uint256 data);
    event Set(DSPC.ParamChange[] updates);

    function setUp() public {
        vm.createSelectFork("mainnet");
        dss = MCD.loadFromChainlog(CHAINLOG);
        pause = dss.chainlog.getAddress("MCD_PAUSE");
        pauseProxy = ProxyLike(dss.chainlog.getAddress("MCD_PAUSE_PROXY"));
        susds = SUSDSLike(dss.chainlog.getAddress("SUSDS"));
        MCD.giveAdminAccess(dss);

        caller = new InitCaller();

        conv = ConvLike(address(new ConvMock()));

        DSPCInstance memory inst = DSPCDeploy.deploy(
            DSPCDeployParams({
                deployer: address(this),
                owner: address(pauseProxy),
                jug: address(dss.jug),
                pot: address(dss.pot),
                susds: address(susds),
                conv: address(conv)
            })
        );
        dspc = DSPC(inst.dspc);
        mom = DSPCMom(inst.mom);

        // Simulate a spell casting
        vm.prank(pause);
        pauseProxy.exec(address(caller), abi.encodeCall(caller.init, (dss, inst)));

        // The init script does not cover setting ilk specific parameters
        vm.startPrank(address(pauseProxy));
        {
            dspc.file(ILK, "max", 30000);
            dspc.file(ILK, "min", 1);
            dspc.file(ILK, "step", 100);
            dspc.file(DSR, "max", 30000);
            dspc.file(DSR, "min", 1);
            dspc.file(DSR, "step", 100);
            dspc.file(SSR, "max", 30000);
            dspc.file(SSR, "min", 1);
            dspc.file(SSR, "step", 100);
            dspc.kiss(bud);
        }
        vm.stopPrank();
    }

    function test_constructor() public view {
        assertEq(address(dspc.jug()), address(dss.jug));
        assertEq(address(dspc.pot()), address(dss.pot));
        assertEq(address(dspc.susds()), address(susds));
        assertEq(address(dspc.conv()), address(conv));

        // init
        assertEq(dspc.wards(address(this)), 0);
        assertEq(dspc.wards(address(pauseProxy)), 1);
        assertEq(dspc.wards(address(mom)), 1);
        assertEq(mom.authority(), dss.chainlog.getAddress("MCD_ADM"));
        assertEq(dss.jug.wards(address(dspc)), 1);
        assertEq(dss.pot.wards(address(dspc)), 1);
        assertEq(SUSDSLike(dss.chainlog.getAddress("SUSDS")).wards(address(dspc)), 1);
    }

    function test_auth() public {
        checkAuth(address(dspc), "DSPC");
    }

    function test_file() public {
        vm.startPrank(address(pauseProxy));

        assertEq(dspc.bad(), 0);
        dspc.file("bad", 1);
        assertEq(dspc.bad(), 1);

        vm.expectRevert("DSPC/invalid-bad-value");
        dspc.file("bad", 2);

        vm.expectRevert("DSPC/file-unrecognized-param");
        dspc.file("unknown", 1);

        assertEq(dspc.tau(), 0);
        dspc.file("tau", 1 days);
        assertEq(dspc.tau(), 1 days);

        vm.stopPrank();
    }

    function test_file_ilk() public {
        assertEq(dspc.cfgs(ILK).min, 1);
        assertEq(dspc.cfgs(ILK).max, 30000);
        assertEq(dspc.cfgs(ILK).step, 100);

        vm.startPrank(address(pauseProxy));
        dspc.file(ILK, "min", 100);
        dspc.file(ILK, "max", 3000);
        dspc.file(ILK, "step", 420);
        vm.stopPrank();

        assertEq(dspc.cfgs(ILK).min, 100);
        assertEq(dspc.cfgs(ILK).max, 3000);
        assertEq(dspc.cfgs(ILK).step, 420);
    }

    function test_file_ilk_invalid() public {
        vm.startPrank(address(pauseProxy));
        DSPC.Cfg memory cfg = dspc.cfgs(ILK);

        vm.expectRevert("DSPC/min-too-high");
        dspc.file(ILK, "min", cfg.max + 1);

        vm.expectRevert("DSPC/max-too-low");
        dspc.file(ILK, "max", cfg.min - 1);

        vm.expectRevert("DSPC/file-unrecognized-param");
        dspc.file(ILK, "unknown", 100);

        vm.expectRevert("DSPC/invalid-value");
        dspc.file(ILK, "max", uint256(type(uint16).max) + 1);

        vm.stopPrank();
    }

    function test_set_ilk() public {
        (uint256 duty,) = dss.jug.ilks(ILK);
        uint256 target = conv.rtob(duty) + 50;

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(ILK, target);

        vm.prank(bud);
        dspc.set(updates);

        (duty,) = dss.jug.ilks(ILK);
        assertEq(duty, conv.btor(target));
    }

    function test_set_dsr() public {
        uint256 target = conv.rtob(dss.pot.dsr()) + 50;

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(DSR, target);

        vm.prank(bud);
        dspc.set(updates);

        assertEq(dss.pot.dsr(), conv.btor(target));
    }

    function test_set_ssr() public {
        vm.prank(bud);
        uint256 target = conv.rtob(susds.ssr()) - 50;

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(SSR, target);

        vm.prank(bud);
        dspc.set(updates);

        assertEq(susds.ssr(), conv.btor(target));
    }

    function test_set_multiple() public {
        (uint256 duty,) = dss.jug.ilks(ILK);
        uint256 ilkTarget = conv.rtob(duty) - 50;
        uint256 dsrTarget = conv.rtob(dss.pot.dsr()) - 50;
        uint256 ssrTarget = conv.rtob(susds.ssr()) + 50;

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](3);
        updates[0] = DSPC.ParamChange(ILK, ilkTarget);
        updates[1] = DSPC.ParamChange(DSR, dsrTarget);
        updates[2] = DSPC.ParamChange(SSR, ssrTarget);

        vm.prank(bud);
        dspc.set(updates);

        (duty,) = dss.jug.ilks(ILK);
        assertEq(duty, conv.btor(ilkTarget));
        assertEq(dss.pot.dsr(), conv.btor(dsrTarget));
        assertEq(susds.ssr(), conv.btor(ssrTarget));
    }

    function test_set_empty() public {
        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](0);

        vm.expectRevert("DSPC/empty-batch");
        vm.prank(bud);
        dspc.set(updates);
    }

    function test_set_unauthorized() public {
        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(ILK, 100);

        vm.expectRevert("DSPC/not-facilitator");
        dspc.set(updates);
    }

    function test_set_below_min() public {
        vm.prank(address(pauseProxy));
        dspc.file(ILK, "min", 100);

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(ILK, 50);

        vm.expectRevert("DSPC/below-min");
        vm.prank(bud);
        dspc.set(updates);
    }

    function test_set_above_max() public {
        vm.prank(address(pauseProxy));
        dspc.file(ILK, "max", 100);

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(ILK, 150);

        vm.expectRevert("DSPC/above-max");
        vm.prank(bud);
        dspc.set(updates);
    }

    function test_set_delta_above_step() public {
        vm.prank(address(pauseProxy));
        dspc.file(ILK, "step", 100);

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(ILK, 100);

        vm.expectRevert("DSPC/delta-above-step");
        vm.prank(bud);
        dspc.set(updates);
    }

    function test_set_before_cooldown() public {
        vm.prank(address(pauseProxy));
        dspc.file("tau", 100);
        uint256 currentDSR = conv.rtob(dss.pot.dsr());

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(DSR, currentDSR + 50);
        vm.prank(bud);
        dspc.set(updates);

        updates[0] = DSPC.ParamChange(DSR, currentDSR + 150);
        vm.prank(bud);
        vm.expectRevert("DSPC/delta-above-step");
        dspc.set(updates);

        updates[0] = DSPC.ParamChange(DSR, currentDSR + 80);
        vm.prank(bud);
        dspc.set(updates);
    }

    function test_pin_updates_after_cooldown() public {
        vm.prank(address(pauseProxy));
        dspc.file("tau", 100);
        uint256 currentDSR = conv.rtob(dss.pot.dsr());

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(DSR, currentDSR + 50);
        vm.prank(bud);
        dspc.set(updates);

        vm.warp(block.timestamp + 101);

        updates[0] = DSPC.ParamChange(DSR, currentDSR + 150);
        vm.prank(bud);
        dspc.set(updates);

        DSPC.Cfg memory cfg = dspc.cfgs(DSR);
        assertEq(cfg.pin, currentDSR + 50);
        assertEq(cfg.toc, block.timestamp);
    }

    function test_multiple_changes_within_step() public {
        vm.startPrank(address(pauseProxy));
        dspc.file("tau", 100);
        dspc.file(DSR, "step", 50);
        vm.stopPrank();

        uint256 currentDSR = conv.rtob(dss.pot.dsr());

        DSPC.ParamChange[] memory updates = new DSPC.ParamChange[](1);
        updates[0] = DSPC.ParamChange(DSR, currentDSR + 20);
        vm.prank(bud);
        dspc.set(updates);

        updates[0] = DSPC.ParamChange(DSR, currentDSR + 40);
        vm.prank(bud);
        dspc.set(updates);

        updates[0] = DSPC.ParamChange(DSR, currentDSR + 10);
        vm.prank(bud);
        dspc.set(updates);

        updates[0] = DSPC.ParamChange(DSR, currentDSR + 51);
        vm.prank(bud);
        vm.expectRevert("DSPC/delta-above-step");
        dspc.set(updates);
    }
}
