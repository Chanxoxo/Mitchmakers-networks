using Godot;
using System;

public class InteractableUI : CanvasLayer
{
	[Export]
	NodePath interactionLabelNodePath;
	RichTextLabel interactionLabel;

	public override void _Ready()
	{
		GetParent().Connect(nameof(Character.InteractableUpdated), this, nameof(InteractableUpdatedCallback));

		interactionLabel = GetNode<RichTextLabel>(interactionLabelNodePath);
	}

	private void InteractableUpdatedCallback(Godot.Object interactableObject) {
		var interactable = interactableObject as IInteractable;
		if (interactable == null || !interactable.CanInteract(GetParent())) {
			interactionLabel.Text = "";
		} else {
			interactionLabel.Text = interactable.InteractionText;
		}
	}
}
