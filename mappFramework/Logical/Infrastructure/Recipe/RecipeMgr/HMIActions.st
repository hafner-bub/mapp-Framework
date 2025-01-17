ACTION FormatDeviceDataProvider:

	// Select CF device if USB device is not available
	FOR i := 0 TO ((SIZEOF(gUSBAvailable) / SIZEOF(gUSBAvailable[0])) - 1) DO
		IF gUSBAvailable[i] THEN
			HmiRecipe.Status.DeviceDataProvider[i + 1] := '{"value":"USB';
			brsitoa(i + 1, ADR(HmiRecipe.Status.DeviceDataProvider[i + 1]) + brsstrlen(ADR(HmiRecipe.Status.DeviceDataProvider[i + 1])));
			brsstrcat(ADR(HmiRecipe.Status.DeviceDataProvider[i + 1]), ADR('","text":"USB'));
			brsitoa(i + 1, ADR(HmiRecipe.Status.DeviceDataProvider[i + 1]) + brsstrlen(ADR(HmiRecipe.Status.DeviceDataProvider[i + 1])));
			brsstrcat(ADR(HmiRecipe.Status.DeviceDataProvider[i + 1]), ADR('"}'));
			MpFileManagerUIConnect.DeviceList.DeviceNames[i + 1] := 'USB';
			brsitoa(i + 1, ADR(MpFileManagerUIConnect.DeviceList.DeviceNames[i + 1]) + brsstrlen(ADR(MpFileManagerUIConnect.DeviceList.DeviceNames[i + 1])));
		ELSE
			brsmemset(ADR(HmiRecipe.Status.DeviceDataProvider[i + 1]), 0, SIZEOF(HmiRecipe.Status.DeviceDataProvider[i + 1]));
			brsmemset(ADR(MpFileManagerUIConnect.DeviceList.DeviceNames[i + 1]), 0, SIZEOF(MpFileManagerUIConnect.DeviceList.DeviceNames[i + 1]));
		END_IF
	END_FOR
	
END_ACTION

ACTION LoadStatus:
	// Configure visible recipe list
	IF MpRecipeUIConnect.Recipe.List.Names[0] = '' THEN
		HmiRecipe.Status.TableConfig := '{ "specRows": [{"from":0,"to":19, "visible":false}]}';
	ELSE
		HmiRecipe.Status.TableConfig := '{ "specRows": [{"from":';
		brsitoa(MpRecipeUIConnect.Recipe.List.MaxSelection + 1, ADR(HmiRecipe.Status.TableConfig) + brsstrlen(ADR(HmiRecipe.Status.TableConfig)));
		brsstrcat(ADR(HmiRecipe.Status.TableConfig), ADR(',"to":19, "visible":false}]}'));
	END_IF

	HmiRecipe.Status.FilesAvailable := (MpRecipeUIConnect.Recipe.List.Names[0] <> '');
	HmiRecipe.Status.LoadAllowed := HmiRecipe.Status.FilesAvailable AND NOT HmiRecipe.Status.InvalidRecipe;
	HmiRecipe.Status.DeviceValid := (MpFileManagerUIRecipe.StatusID <> mpFILE_ERR_INVALID_FILE_DEV);
	
	IF HmiRecipe.Status.SelectedIndex > MpRecipeUIConnect.Recipe.List.MaxSelection THEN
		HmiRecipe.Status.SelectedIndex := MpRecipeUIConnect.Recipe.List.MaxSelection;
	END_IF	

	MpRecipeUIConnect.Recipe.List.SelectedIndex := HmiRecipe.Status.SelectedIndex;
	
END_ACTION

ACTION LoadPreview:

	
	CASE HmiRecipe.Status.PreviewCase OF
		PREVIEW_WAIT:
			// Load preview when a recipe is selected
			IF ((HmiRecipe.Status.SelectedIndex <> HmiRecipe.Status.LastSelectedIndex) OR (HmiRecipe.Status.LastMaxSelection <> MpRecipeUIConnect.Recipe.List.MaxSelection)
				OR (HmiRecipe.Status.PreviousRangeStart <> MpRecipeUIConnect.Recipe.List.RangeStart) OR (HmiRecipe.Status.PreviousRangeStart <> MpRecipeUIConnect.Recipe.List.RangeStart))
				AND (MpRecipeUIConnect.Status = mpRECIPE_UI_STATUS_IDLE) THEN
				HmiRecipe.Status.PreviewCase := PREVIEW_LOAD;
			END_IF
			
		PREVIEW_LOAD:
			// Check selected recipe name is not empty
			IF (brsstrlen(ADR(MpRecipeUIConnect.Recipe.List.Names[HmiRecipe.Status.SelectedIndex])) > 0) AND (HmiRecipe.Status.HMIcommand = REC_HMI_WAIT) THEN
				MpRecipeSys.FileName := ADR(MpRecipeUIConnect.Recipe.List.Names[HmiRecipe.Status.SelectedIndex]);
				MpRecipeSys.Category := ADR(HmiRecipe.Parameters.Category);
				MpRecipeSys.Load := TRUE;
				HmiRecipe.Status.LastSelectedIndex := HmiRecipe.Status.SelectedIndex;
				HmiRecipe.Status.LastMaxSelection := MpRecipeUIConnect.Recipe.List.MaxSelection;
				HmiRecipe.Status.PreviousRangeStart := MpRecipeUIConnect.Recipe.List.RangeStart;
				HmiRecipe.Status.PreviousRangeEnd := MpRecipeUIConnect.Recipe.List.RangeEnd;
				HmiRecipe.Status.InvalidRecipe := FALSE;
				HmiRecipe.Status.PreviewCase := PREVIEW_CHANGE;
			END_IF
			
		PREVIEW_CHANGE:
			//Load a second time to ensure correct preview on page up/page down
			MpRecipeSys.Load := TRUE;	
			HmiRecipe.Status.PreviewCase := PREVIEW_WAIT;

	END_CASE;

	// Reset load command on MpRecipeSys FUB
	IF MpRecipeSys.StatusID <> 0 THEN
		HmiRecipe.Status.InvalidRecipe := TRUE;
		HmiRecipe.Commands.ResetPreview := TRUE;
	END_IF;

	IF ((MpRecipeSys.CommandDone) OR (MpRecipeSys.Error)) THEN
		MpRecipeSys.Load := FALSE;
	END_IF

END_ACTION

ACTION RecipeHMIcommands:

	CASE HmiRecipe.Status.HMIcommand OF
		REC_HMI_WAIT:
			// The following commands are triggered directly from the HMI. If you imported the mapp View front end of
			// the Framework, then this is already taken care of. If you did not, then your visualization must
			// trigger each one of these command variables (CreateRecipe, SaveSelectedRecipe, LoadRecipe).
			IF (MpRecipeUIConnect.Status <> mpRECIPE_UI_STATUS_IDLE) THEN
				// MpRecipe is active so don't issue a new command
			ELSIF HmiRecipe.Commands.CreateRecipe THEN
				HmiRecipe.Status.HMIcommand := REC_HMI_CREATE;
				HmiRecipe.Commands.CreateRecipe := FALSE;
			ELSIF HmiRecipe.Commands.SaveSelectedRecipe THEN
				HmiRecipe.Status.HMIcommand := REC_HMI_SAVE;
				HmiRecipe.Commands.SaveSelectedRecipe := FALSE;
			ELSIF HmiRecipe.Commands.LoadRecipe THEN
				HmiRecipe.Status.HMIcommand := REC_HMI_LOAD;
				HmiRecipe.Commands.LoadRecipe := FALSE;
				IF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(PARAMETERS_RECIPE)) = 0) THEN
					HmiRecipe.Status.ProductRecipeLoaded := FALSE;
				ELSE
					HmiRecipe.Status.ConfigRecipeLoaded := FALSE;
				END_IF
			ELSIF HmiRecipe.Commands.ResetPreview THEN
				HmiRecipe.Status.HMIcommand := REC_HMI_RESET_PREVIEW;
				HmiRecipe.Commands.ResetPreview := FALSE;
			END_IF

		REC_HMI_CREATE:
			IF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(PARAMETERS_RECIPE)) = 0) THEN
				ParametersPreview := ParametersEdit;
				brsstrcpy(ADR(MpRecipeUIConnect.New.FileName), ADR(HmiRecipe.Parameters.FileName));
				brsstrcat(ADR(MpRecipeUIConnect.New.FileName), ADR('.par'));
				// If the default recipe was initially missing and just now created, immediately load it
				IF HmiRecipe.Status.ParameterRecipeMissing THEN
					HmiRecipe.Commands.LoadRecipe := TRUE;
				END_IF
			ELSIF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(MACHINE_CONFIGURATION_RECIPE)) = 0) THEN
				MachineSettingsPreview := MachineSettingsEdit;
				brsstrcpy(ADR(MpRecipeUIConnect.New.FileName), ADR(HmiRecipe.Parameters.FileName));
				brsstrcat(ADR(MpRecipeUIConnect.New.FileName), ADR('.mcfg'));
				// If the default recipe was initially missing and just now created, immediately load it
				IF HmiRecipe.Status.MachineSettingsRecipeMissing THEN
					HmiRecipe.Commands.LoadRecipe := TRUE;
				END_IF
			END_IF

			Header.Name := MpRecipeUIConnect.New.FileName;
			DTGetTimeRecipe.enable := TRUE;
			REPEAT
				DTGetTimeRecipe();
				UNTIL (DTGetTimeRecipe.status = 0)
			END_REPEAT;
			Header.DateTime := DTGetTimeRecipe.DT1;
			DTGetTimeRecipe.enable := FALSE;
			DTGetTimeRecipe();
			MpRecipeUIConnect.New.Create := TRUE;

			HmiRecipe.Status.HMIcommand := REC_HMI_WAIT;

		REC_HMI_LOAD:
			IF (MpRecipeUIConnect.Status = mpRECIPE_UI_STATUS_IDLE) THEN
				IF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(PARAMETERS_RECIPE)) = 0) THEN
					Parameters := ParametersPreview;
					HmiRecipe.Status.ProductRecipeLoaded := TRUE;
					// If the default recipe was initially missing and just now created, then it is the last loaded recipe
					IF HmiRecipe.Status.ParameterRecipeMissing THEN
						HmiRecipe.Status.LastLoadedProductRecipe := DEFAULT_PARAMETERS;
						brsstrcat(ADR(HmiRecipe.Status.LastLoadedProductRecipe), ADR(PARAMETERS_FILE_EXTENSION));
						HmiRecipeRetain.LastLoadedProductRecipe := HmiRecipe.Status.LastLoadedProductRecipe;
						HmiRecipe.Status.ParameterRecipeMissing := FALSE;
						// Otherwise, the last loaded recipe is the selected recipe
					ELSE
						HmiRecipe.Status.LastLoadedProductRecipe := MpRecipeUIConnect.Recipe.List.Names[HmiRecipe.Status.SelectedIndex];
						HmiRecipeRetain.LastLoadedProductRecipe := MpRecipeUIConnect.Recipe.List.Names[HmiRecipe.Status.SelectedIndex];
					END_IF
				ELSIF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(MACHINE_CONFIGURATION_RECIPE)) = 0) THEN
					MachineSettings := MachineSettingsPreview;
					HmiRecipe.Status.ConfigRecipeLoaded := TRUE;
					// If the default recipe was initially missing and just now created, then it is the last loaded recipe
					IF HmiRecipe.Status.MachineSettingsRecipeMissing THEN
						HmiRecipe.Status.LastLoadedConfigRecipe := DEFAULT_MACHINE_CONFIGURATION;
						brsstrcat(ADR(HmiRecipe.Status.LastLoadedConfigRecipe), ADR(MACHINE_CONFIG_FILE_EXTENSION));
						HmiRecipeRetain.LastLoadedConfigRecipe := HmiRecipe.Status.LastLoadedConfigRecipe;
						HmiRecipe.Status.MachineSettingsRecipeMissing := FALSE;
						// Otherwise, the last loaded recipe is the selected recipe
					ELSE
						HmiRecipe.Status.LastLoadedConfigRecipe := MpRecipeUIConnect.Recipe.List.Names[HmiRecipe.Status.SelectedIndex];
						HmiRecipeRetain.LastLoadedConfigRecipe := MpRecipeUIConnect.Recipe.List.Names[HmiRecipe.Status.SelectedIndex];
					END_IF
				END_IF
				HmiRecipe.Status.HMIcommand := REC_HMI_WAIT;
			END_IF

		REC_HMI_SAVE:
			IF (MpRecipeUIConnect.Status = mpRECIPE_UI_STATUS_IDLE) THEN

				IF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(PARAMETERS_RECIPE)) = 0) THEN
					ParametersPreview := ParametersEdit;
				ELSIF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(MACHINE_CONFIGURATION_RECIPE)) = 0) THEN
					MachineSettingsPreview := MachineSettingsEdit;
				END_IF

				IF (brsstrlen(ADR(HmiRecipe.Status.SelectedRecipe)) > 0) THEN
					MpRecipeSys.FileName := ADR(HmiRecipe.Status.SelectedRecipe);
					MpRecipeSys.Save := TRUE;
				END_IF

				HmiRecipe.Status.HMIcommand := REC_HMI_WAIT;
			END_IF

		REC_HMI_RESET_PREVIEW:
			IF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(PARAMETERS_RECIPE)) = 0) THEN
				brsmemset(ADR(ParametersPreview), 0, SIZEOF(ParametersPreview));
			ELSIF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(MACHINE_CONFIGURATION_RECIPE)) = 0) THEN
				brsmemset(ADR(MachineSettingsPreview), 0, SIZEOF(MachineSettingsPreview));
			END_IF
			HmiRecipe.Status.HMIcommand := REC_HMI_WAIT;

	END_CASE

	//	IF NOT MpRecipeSys.CommandBusy AND brsstrcmp(ADR(HmiRecipe.Status.PreviousRecipe), ADR(HmiRecipe.Parameters.FileName)) <> 0 THEN
	//		HmiRecipe.Parameters.FileName := HmiRecipe.Status.PreviousRecipe;
	//	END_IF

	// If the Edit or Create dialog boxes open, copy the Preview structure into the Edit structure.
	IF HmiRecipe.Status.EditDialogOpened OR HmiRecipe.Status.CreateDialogOpened THEN
		IF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(PARAMETERS_RECIPE)) = 0) THEN
			ParametersEdit := ParametersPreview;
			IF HmiRecipe.Status.ParameterRecipeMissing THEN
				HmiRecipe.Parameters.FileName := DEFAULT_PARAMETERS;
			ELSE
				HmiRecipe.Parameters.FileName:= 'newParameters';
			END_IF
		ELSIF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(MACHINE_CONFIGURATION_RECIPE)) = 0) THEN
			MachineSettingsEdit := MachineSettingsPreview;
			IF HmiRecipe.Status.MachineSettingsRecipeMissing THEN
				HmiRecipe.Parameters.FileName := DEFAULT_MACHINE_CONFIGURATION;
			ELSE
				HmiRecipe.Parameters.FileName := 'newMachineConfig';
			END_IF
		END_IF
		HmiRecipe.Status.EditDialogOpened := FALSE;
		HmiRecipe.Status.CreateDialogOpened := FALSE;
	END_IF

	// Check if the file name has already been used
	HmiRecipe.Status.FileDuplicate := FALSE;
	FOR i:=0 TO ((SIZEOF(MpRecipeUIConnect.Recipe.List.Names) / SIZEOF(MpRecipeUIConnect.Recipe.List.Names[0])) - 1) DO
		temp := HmiRecipe.Parameters.FileName;
		IF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(PARAMETERS_RECIPE)) = 0) THEN
			brsstrcat(ADR(temp),ADR(PARAMETERS_FILE_EXTENSION));
		ELSIF (brsstrcmp(ADR(HmiRecipe.Parameters.Category), ADR(MACHINE_CONFIGURATION_RECIPE)) = 0) THEN
			brsstrcat(ADR(temp),ADR(MACHINE_CONFIG_FILE_EXTENSION));
		END_IF
		IF temp = MpRecipeUIConnect.Recipe.List.Names[i] THEN
			HmiRecipe.Status.FileDuplicate := TRUE;
		END_IF
	END_FOR

	// Set whether the loading .gif should be shown on the HMI
	HmiRecipe.Status.LoadingRecipeList := (MpRecipeUIConnect.Status = mpRECIPE_UI_STATUS_REFRESH);
	HmiRecipe.Status.DefaultRecipeSelected := (HmiRecipe.Status.SelectedRecipe = CONCAT(DEFAULT_PARAMETERS,PARAMETERS_FILE_EXTENSION)) OR (HmiRecipe.Status.SelectedRecipe = CONCAT(DEFAULT_MACHINE_CONFIGURATION, MACHINE_CONFIG_FILE_EXTENSION));
	
	// Update status information
	HmiRecipe.Status.LastStatus := MpRecipeUIConnect.Status;
	HmiRecipe.Status.SelectedRecipe := MpRecipeUIConnect.Recipe.List.Names[HmiRecipe.Status.SelectedIndex];
	
END_ACTION
