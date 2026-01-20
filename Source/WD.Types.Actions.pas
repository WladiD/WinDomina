// ======================================================================
// Copyright (c) 2026 Waldemar Derr. All rights reserved.
//
// Licensed under the MIT license. See included LICENSE file for details.
// ======================================================================

unit WD.Types.Actions;

interface

type

  TCapsLockAction = (claDoNothing, claActivateWD, claActivateWDIgnoreKey);
  TLeftWinAction = (lwaDoNothing, lwaActivateWD);
  TRightCtrlAction = (rcaDoNothing, rcaContextMenu);

implementation

end.
