package dev.assetpipeline.androidhost

import org.junit.Assert.assertEquals
import org.junit.Test

class MountPolicyTest {
    @Test fun aHuggingRootKeepsItsContentHeight() {
        assertEquals(MountPolicy.WRAP, MountPolicy.rootHeight(rootFills = false, hasContainer = true, containerInnerHeight = 2151))
        assertEquals(MountPolicy.WRAP, MountPolicy.rootHeight(rootFills = false, hasContainer = false, containerInnerHeight = 0))
    }

    @Test fun aFillingRootTakesTheContainersInnerHeightOnceLaidOut() {
        assertEquals(2151, MountPolicy.rootHeight(rootFills = true, hasContainer = true, containerInnerHeight = 2151))
        assertEquals(MountPolicy.WRAP, MountPolicy.rootHeight(rootFills = true, hasContainer = true, containerInnerHeight = 0))
    }

    @Test fun aFillingRootWithNoContainerMatchesItsParent() {
        assertEquals(MountPolicy.MATCH, MountPolicy.rootHeight(rootFills = true, hasContainer = false, containerInnerHeight = 0))
    }
}
